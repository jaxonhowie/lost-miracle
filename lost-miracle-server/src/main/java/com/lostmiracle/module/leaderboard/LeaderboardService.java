package com.lostmiracle.module.leaderboard;

import com.lostmiracle.common.BusinessException;
import com.lostmiracle.common.ErrorCode;
import com.lostmiracle.module.character.entity.CharacterEntity;
import com.lostmiracle.module.character.mapper.CharacterMapper;
import com.lostmiracle.module.leaderboard.dto.LeaderboardEntryResponse;
import com.lostmiracle.module.leaderboard.dto.LeaderboardResponse;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ZSetOperations;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;
import java.util.Set;

@Service
public class LeaderboardService {

    public static final String BOARD_POWER = "power";

    private final StringRedisTemplate redisTemplate;
    private final CharacterMapper characterMapper;

    public LeaderboardService(StringRedisTemplate redisTemplate, CharacterMapper characterMapper) {
        this.redisTemplate = redisTemplate;
        this.characterMapper = characterMapper;
    }

    public void submitPowerScore(CharacterEntity character) {
        String key = redisKey(BOARD_POWER, "all");
        redisTemplate.opsForZSet().add(key, String.valueOf(character.getId()), character.getPowerScore());
    }

    public void removeCharacter(long characterId) {
        redisTemplate.opsForZSet().remove(redisKey(BOARD_POWER, "all"), String.valueOf(characterId));
    }

    public LeaderboardResponse getLeaderboard(String boardType, String season, int page, int pageSize, Long viewerCharacterId) {
        if (!BOARD_POWER.equals(boardType)) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "unsupported board type");
        }
        String key = redisKey(boardType, season);
        int start = Math.max(0, (page - 1) * pageSize);
        int end = start + pageSize - 1;

        Set<ZSetOperations.TypedTuple<String>> tuples = redisTemplate.opsForZSet()
                .reverseRangeWithScores(key, start, end);
        List<LeaderboardEntryResponse> items = new ArrayList<>();
        if (tuples != null) {
            int rank = start + 1;
            for (ZSetOperations.TypedTuple<String> tuple : tuples) {
                if (tuple.getValue() == null || tuple.getScore() == null) {
                    continue;
                }
                long characterId = Long.parseLong(tuple.getValue());
                CharacterEntity character = characterMapper.selectById(characterId);
                if (character == null) {
                    continue;
                }
                items.add(new LeaderboardEntryResponse(
                        rank++,
                        character.getId(),
                        character.getName(),
                        character.getPlayerClass(),
                        character.getLevel(),
                        tuple.getScore().longValue(),
                        character.getCurrentDungeonId()
                ));
            }
        }

        Integer myRank = null;
        Long myScore = null;
        if (viewerCharacterId != null) {
            Long rank = redisTemplate.opsForZSet().reverseRank(key, String.valueOf(viewerCharacterId));
            Double score = redisTemplate.opsForZSet().score(key, String.valueOf(viewerCharacterId));
            if (rank != null) {
                myRank = rank.intValue() + 1;
            }
            if (score != null) {
                myScore = score.longValue();
            }
        }

        return new LeaderboardResponse(boardType, season, myRank, myScore, items);
    }

    private String redisKey(String boardType, String season) {
        return "lb:" + boardType + ":" + season;
    }
}
