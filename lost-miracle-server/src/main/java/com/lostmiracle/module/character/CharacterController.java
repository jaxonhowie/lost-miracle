package com.lostmiracle.module.character;

import com.lostmiracle.common.ApiResponse;
import com.lostmiracle.module.character.dto.CharacterListResponse;
import com.lostmiracle.module.character.dto.CharacterSummaryResponse;
import com.lostmiracle.module.character.dto.CreateCharacterRequest;
import com.lostmiracle.module.character.dto.UpdateCharacterRequest;
import com.lostmiracle.security.SecurityUtils;
import com.lostmiracle.security.UserPrincipal;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/characters")
public class CharacterController {

    private final CharacterService characterService;

    public CharacterController(CharacterService characterService) {
        this.characterService = characterService;
    }

    @GetMapping
    public ApiResponse<CharacterListResponse> list() {
        UserPrincipal principal = SecurityUtils.requirePrincipal();
        return ApiResponse.ok(characterService.listCharacters(principal.userId()));
    }

    @PostMapping
    public ApiResponse<CharacterSummaryResponse> create(@Valid @RequestBody(required = false) CreateCharacterRequest request) {
        UserPrincipal principal = SecurityUtils.requirePrincipal();
        CreateCharacterRequest body = request == null ? new CreateCharacterRequest(null) : request;
        return ApiResponse.ok(characterService.createCharacter(principal.userId(), body));
    }

    @PatchMapping("/{characterId}")
    public ApiResponse<CharacterSummaryResponse> update(
            @PathVariable long characterId,
            @Valid @RequestBody UpdateCharacterRequest request
    ) {
        UserPrincipal principal = SecurityUtils.requirePrincipal();
        return ApiResponse.ok(characterService.updateCharacter(principal.userId(), characterId, request));
    }

    @DeleteMapping("/{characterId}")
    public ApiResponse<Void> delete(@PathVariable long characterId) {
        UserPrincipal principal = SecurityUtils.requirePrincipal();
        characterService.deleteCharacter(principal.userId(), characterId);
        return ApiResponse.ok(null);
    }
}
