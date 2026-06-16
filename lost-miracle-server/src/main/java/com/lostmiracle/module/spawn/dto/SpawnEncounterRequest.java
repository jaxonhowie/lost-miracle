package com.lostmiracle.module.spawn.dto;

import jakarta.validation.constraints.NotBlank;

public record SpawnEncounterRequest(
        @NotBlank String type
) {
}
