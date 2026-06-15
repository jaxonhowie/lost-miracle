package com.lostmiracle.module.mail;

import com.lostmiracle.common.ApiResponse;
import com.lostmiracle.module.mail.dto.ClaimMailRequest;
import com.lostmiracle.module.mail.dto.ClaimMailResponse;
import com.lostmiracle.module.mail.dto.MailListResponse;
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
@RequestMapping("/characters/{characterId}/mail")
public class MailController {

    private final MailService mailService;

    public MailController(MailService mailService) {
        this.mailService = mailService;
    }

    @GetMapping
    public ApiResponse<MailListResponse> list(@PathVariable long characterId) {
        UserPrincipal principal = SecurityUtils.requirePrincipal();
        return ApiResponse.ok(mailService.listMail(principal.userId(), characterId));
    }

    @PostMapping("/{mailId}/claim")
    public ApiResponse<ClaimMailResponse> claim(
            @PathVariable long characterId,
            @PathVariable long mailId,
            @Valid @RequestBody ClaimMailRequest request
    ) {
        UserPrincipal principal = SecurityUtils.requirePrincipal();
        return ApiResponse.ok(mailService.claim(principal.userId(), characterId, mailId, request));
    }
}
