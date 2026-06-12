package com.lostmiracle.module.character.dto;

import jakarta.validation.constraints.Size;

public record CreateCharacterRequest(
        @Size(max = 32) String name
) {
}
