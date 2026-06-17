package com.lostmiracle.module.spawn;

import com.lostmiracle.common.ApiResponse;
import com.lostmiracle.module.character.CharacterService;
import com.lostmiracle.module.spawn.dto.DungeonSpawnStateResponse;
import com.lostmiracle.module.spawn.dto.SpawnEncounterRequest;
import com.lostmiracle.module.spawn.dto.SpawnEncounterResponse;
import com.lostmiracle.module.spawn.dto.SpawnSettleRequest;
import com.lostmiracle.module.spawn.dto.SpawnSettleResponse;
import com.lostmiracle.security.SecurityUtils;
import com.lostmiracle.security.UserPrincipal;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/characters/{characterId}/dungeons/{dungeonId}/spawns")
public class SpawnController {

    private final SpawnService spawnService;
    private final SpawnSettleService spawnSettleService;
    private final CharacterService characterService;

    public SpawnController(
            SpawnService spawnService,
            SpawnSettleService spawnSettleService,
            CharacterService characterService
    ) {
        this.spawnService = spawnService;
        this.spawnSettleService = spawnSettleService;
        this.characterService = characterService;
    }

    @GetMapping
    public ApiResponse<DungeonSpawnStateResponse> state(
            @PathVariable long characterId,
            @PathVariable String dungeonId
    ) {
        requireOwned(characterId);
        return ApiResponse.ok(spawnService.getState(dungeonId));
    }

    @PostMapping("/encounter")
    public ApiResponse<SpawnEncounterResponse> encounter(
            @PathVariable long characterId,
            @PathVariable String dungeonId,
            @Valid @RequestBody SpawnEncounterRequest request
    ) {
        requireOwned(characterId);
        return ApiResponse.ok(spawnService.encounter(characterId, dungeonId, request.type()));
    }

    @PostMapping("/{slotId}/settle")
    public ApiResponse<SpawnSettleResponse> settle(
            @PathVariable long characterId,
            @PathVariable String dungeonId,
            @PathVariable long slotId,
            @Valid @RequestBody SpawnSettleRequest request
    ) {
        UserPrincipal principal = SecurityUtils.requirePrincipal();
        return ApiResponse.ok(spawnSettleService.settle(
                principal.userId(),
                characterId,
                dungeonId,
                slotId,
                request
        ));
    }

    @PostMapping("/{slotId}/defeat")
    public ApiResponse<Void> defeat(
            @PathVariable long characterId,
            @PathVariable String dungeonId,
            @PathVariable long slotId
    ) {
        requireOwned(characterId);
        spawnService.defeat(characterId, slotId);
        return ApiResponse.ok(null);
    }

    @PostMapping("/{slotId}/release")
    public ApiResponse<Void> release(
            @PathVariable long characterId,
            @PathVariable String dungeonId,
            @PathVariable long slotId
    ) {
        requireOwned(characterId);
        spawnService.release(characterId, slotId);
        return ApiResponse.ok(null);
    }

    private void requireOwned(long characterId) {
        UserPrincipal principal = SecurityUtils.requirePrincipal();
        characterService.requireOwnedCharacter(principal.userId(), characterId);
    }
}
