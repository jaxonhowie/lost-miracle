package com.lostmiracle.module.admin;

import com.lostmiracle.common.BusinessException;
import com.lostmiracle.common.ErrorCode;
import com.lostmiracle.config.LostMiracleProperties;
import com.lostmiracle.module.admin.dto.GmAuthResponse;
import com.lostmiracle.module.admin.dto.GmLoginRequest;
import com.lostmiracle.module.admin.dto.GmMeResponse;
import com.lostmiracle.module.admin.entity.GmAccountEntity;
import com.lostmiracle.module.admin.mapper.GmAccountMapper;
import com.lostmiracle.security.AdminJwtTokenProvider;
import com.lostmiracle.security.GmPrincipal;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

@Service
public class AdminAuthService {

    private static final Logger log = LoggerFactory.getLogger(AdminAuthService.class);

    private final GmAccountMapper gmAccountMapper;
    private final PasswordEncoder passwordEncoder;
    private final AdminJwtTokenProvider adminJwtTokenProvider;
    private final LostMiracleProperties properties;

    public AdminAuthService(
            GmAccountMapper gmAccountMapper,
            PasswordEncoder passwordEncoder,
            AdminJwtTokenProvider adminJwtTokenProvider,
            LostMiracleProperties properties
    ) {
        this.gmAccountMapper = gmAccountMapper;
        this.passwordEncoder = passwordEncoder;
        this.adminJwtTokenProvider = adminJwtTokenProvider;
        this.properties = properties;
    }

    @EventListener(ApplicationReadyEvent.class)
    public void bootstrapSuperAccount() {
        if (gmAccountMapper.countAll() > 0) {
            return;
        }
        GmAccountEntity account = new GmAccountEntity();
        account.setUsername(properties.getGm().getBootstrapSuperUsername());
        account.setPasswordHash(passwordEncoder.encode(properties.getGm().getBootstrapSuperPassword()));
        account.setRole(GmRole.super_.toDbValue());
        account.setStatus(1);
        gmAccountMapper.insert(account);
        log.warn("bootstrapped default gm super account username={}", account.getUsername());
    }

    public GmAuthResponse login(GmLoginRequest request) {
        GmAccountEntity account = gmAccountMapper.selectByUsername(request.username());
        if (account == null || account.getStatus() == null || account.getStatus() != 1) {
            throw new BusinessException(ErrorCode.UNAUTHORIZED, "invalid username or password");
        }
        if (!passwordEncoder.matches(request.password(), account.getPasswordHash())) {
            throw new BusinessException(ErrorCode.UNAUTHORIZED, "invalid username or password");
        }
        GmRole role = GmRole.fromString(account.getRole());
        String token = adminJwtTokenProvider.createToken(account.getId(), account.getUsername(), role);
        return GmAuthResponse.of(token, adminJwtTokenProvider.getExpirationSeconds(), account.getId(), account.getUsername(), role);
    }

    public GmMeResponse me(GmPrincipal principal) {
        return GmMeResponse.from(principal.gmAccountId(), principal.username(), principal.role());
    }
}
