package com.lostmiracle.module.character.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record UpdateCharacterRequest(
        @NotBlank @Size(max = 32) String name
) {
}
