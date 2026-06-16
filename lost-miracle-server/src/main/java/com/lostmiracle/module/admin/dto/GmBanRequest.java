package com.lostmiracle.module.admin.dto;

import jakarta.validation.constraints.NotBlank;

public record GmBanRequest(
        @NotBlank String reason
) {
}
