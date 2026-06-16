package com.lostmiracle.security;

import com.lostmiracle.module.admin.GmRole;

public record GmPrincipal(Long gmAccountId, String username, GmRole role) {
}
