package com.lostmiracle.module.admin.dto;

import jakarta.validation.constraints.NotBlank;

public record GmLoginRequest(
        @NotBlank String username,
        @NotBlank String password
) {
}
