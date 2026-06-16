package com.lostmiracle.module.spawn;

import com.lostmiracle.common.BusinessException;
import com.lostmiracle.common.ErrorCode;
import com.lostmiracle.module.save.RedisLockService;
import com.lostmiracle.module.spawn.dto.DungeonSpawnStateResponse;
import com.lostmiracle.module.spawn.dto.SpawnEncounterResponse;
import com.lostmiracle.module.spawn.dto.SpawnSlotView;
import com.lostmiracle.module.spawn.entity.DungeonSpawnSlotEntity;
import com.lostmiracle.module.spawn.mapper.DungeonSpawnMapper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ThreadLocalRandom;

@Service
public class SpawnService {

    private final DungeonSpawnMapper dungeonSpawnMapper;
    private final MonsterCatalog monsterCatalog;

    public SpawnService(
            DungeonSpawnMapper dungeonSpawnMapper,
            MonsterCatalog monsterCatalog
    ) {
        this.dungeonSpawnMapper = dungeonSpawnMapper;
        this.monsterCatalog = monsterCatalog;
    }

    public DungeonSpawnStateResponse getState(String dungeonId) {
        ensureSeeded(dungeonId);
        long now = Instant.now().getEpochSecond();
        List<DungeonSpawnSlotEntity> slots = dungeonSpawnMapper.selectByDungeonId(dungeonId);

        Map<String, List<SpawnSlotView>> normals = new LinkedHashMap<>();
        SpawnSlotView elite = null;
        SpawnSlotView boss = null;

        for (DungeonSpawnSlotEntity slot : slots) {
            SpawnSlotView view = toView(slot, now);
            switch (slot.getSpawnType()) {
                case SpawnConstants.SPAWN_NORMAL -> {
                    normals.computeIfAbsent(slot.getMonsterId(), ignored -> new ArrayList<>()).add(view);
                }
                case SpawnConstants.SPAWN_ELITE -> elite = view;
                case SpawnConstants.SPAWN_BOSS -> boss = view;
                default -> {
                }
            }
        }
        normals.values().forEach(list -> list.sort(Comparator.comparingInt(SpawnSlotView::slotIndex)));
        return new DungeonSpawnStateResponse(dungeonId, normals, elite, boss);
    }

    @Transactional
    public SpawnEncounterResponse encounter(long characterId, String dungeonId, String type) {
        ensureSeeded(dungeonId);
        long now = Instant.now().getEpochSecond();
        List<DungeonSpawnSlotEntity> candidates = switch (type) {
            case SpawnConstants.SPAWN_NORMAL -> dungeonSpawnMapper.selectAvailableByDungeonAndType(
                    dungeonId, SpawnConstants.SPAWN_NORMAL, now
            );
            case SpawnConstants.SPAWN_ELITE -> dungeonSpawnMapper.selectAvailableByDungeonAndType(
                    dungeonId, SpawnConstants.SPAWN_ELITE, now
            );
            case SpawnConstants.SPAWN_BOSS -> dungeonSpawnMapper.selectAvailableByDungeonAndType(
                    dungeonId, SpawnConstants.SPAWN_BOSS, now
            );
            default -> throw new BusinessException(ErrorCode.BAD_REQUEST, "invalid spawn type");
        };
        if (candidates.isEmpty()) {
            throw new BusinessException(ErrorCode.NOT_FOUND, "no spawn available");
        }
        // 随机尝试占用，避免并发下固定顺序抢槽。
        List<DungeonSpawnSlotEntity> shuffled = new ArrayList<>(candidates);
        shuffled.sort(Comparator.comparingInt(slot -> ThreadLocalRandom.current().nextInt()));
        for (DungeonSpawnSlotEntity picked : shuffled) {
            if (dungeonSpawnMapper.tryEngage(picked.getId(), characterId, now) > 0) {
                String monsterId = resolveMonsterId(dungeonId, picked);
                return new SpawnEncounterResponse(picked.getId(), picked.getSpawnType(), monsterId, picked.getSlotIndex());
            }
        }
        throw new BusinessException(ErrorCode.CONFLICT, "spawn already taken");
    }

    @Transactional
    public void defeat(long characterId, long slotId) {
        DungeonSpawnSlotEntity slot = requireOwnedSlot(characterId, slotId);
        long respawnAt = Instant.now().getEpochSecond() + cooldownFor(slot.getSpawnType());
        if (dungeonSpawnMapper.applyDefeatCooldown(slotId, characterId, respawnAt) == 0) {
            throw new BusinessException(ErrorCode.CONFLICT, "spawn slot state changed");
        }
    }

    @Transactional
    public void release(long characterId, long slotId) {
        if (dungeonSpawnMapper.releaseEngagement(slotId, characterId) == 0) {
            throw new BusinessException(ErrorCode.CONFLICT, "spawn slot not engaged by character");
        }
    }

    private String resolveMonsterId(String dungeonId, DungeonSpawnSlotEntity slot) {
        if (SpawnConstants.SPAWN_ELITE.equals(slot.getSpawnType())
                && SpawnConstants.ELITE_POOL.equals(slot.getMonsterId())) {
            List<String> elites = monsterCatalog.listMonsterIds(dungeonId, SpawnConstants.SPAWN_ELITE);
            if (elites.isEmpty()) {
                throw new BusinessException(ErrorCode.INTERNAL_ERROR, "elite pool empty");
            }
            return elites.get(ThreadLocalRandom.current().nextInt(elites.size()));
        }
        return slot.getMonsterId();
    }

    private DungeonSpawnSlotEntity requireOwnedSlot(long characterId, long slotId) {
        DungeonSpawnSlotEntity slot = dungeonSpawnMapper.selectById(slotId);
        if (slot == null) {
            throw new BusinessException(ErrorCode.NOT_FOUND, "spawn slot not found");
        }
        if (slot.getEngagedCharacterId() == null || !slot.getEngagedCharacterId().equals(characterId)) {
            throw new BusinessException(ErrorCode.FORBIDDEN, "spawn slot not engaged by character");
        }
        return slot;
    }

    private void ensureSeeded(String dungeonId) {
        if (dungeonSpawnMapper.countByDungeonId(dungeonId) == 0) {
            throw new BusinessException(ErrorCode.NOT_FOUND, "dungeon spawn not initialized");
        }
    }

    private int cooldownFor(String spawnType) {
        return switch (spawnType) {
            case SpawnConstants.SPAWN_NORMAL -> SpawnConstants.NORMAL_COOLDOWN_SEC;
            case SpawnConstants.SPAWN_ELITE -> SpawnConstants.ELITE_COOLDOWN_SEC;
            case SpawnConstants.SPAWN_BOSS -> SpawnConstants.BOSS_COOLDOWN_SEC;
            default -> SpawnConstants.NORMAL_COOLDOWN_SEC;
        };
    }

    private SpawnSlotView toView(DungeonSpawnSlotEntity slot, long now) {
        boolean available = slot.getEngagedCharacterId() == null && slot.getRespawnAt() <= now;
        int cooldownSec = available ? 0 : Math.max(0, (int) (slot.getRespawnAt() - now));
        String monsterId = slot.getMonsterId();
        if (SpawnConstants.ELITE_POOL.equals(monsterId)) {
            monsterId = SpawnConstants.ELITE_POOL;
        }
        return new SpawnSlotView(slot.getId(), monsterId, slot.getSlotIndex(), available, cooldownSec);
    }

    @Transactional
    public void adminResetSlot(long slotId) {
        DungeonSpawnSlotEntity slot = dungeonSpawnMapper.selectById(slotId);
        if (slot == null) {
            throw new BusinessException(ErrorCode.NOT_FOUND, "spawn slot not found");
        }
        if (dungeonSpawnMapper.adminResetSlot(slotId) == 0) {
            throw new BusinessException(ErrorCode.INTERNAL_ERROR, "spawn reset failed");
        }
    }

    @Transactional
    public int adminResetDungeon(String dungeonId) {
        ensureSeeded(dungeonId);
        return dungeonSpawnMapper.adminResetDungeon(dungeonId);
    }
}
