package com.lostmiracle.module.mail.dto;

import jakarta.validation.constraints.NotNull;

public record ClaimMailRequest(@NotNull Long saveVersion) {
}
