package com.lostmiracle.module.save;

import com.lostmiracle.common.ApiResponse;
import com.lostmiracle.module.save.dto.SaveDownloadResponse;
import com.lostmiracle.module.save.dto.UploadSaveRequest;
import com.lostmiracle.module.save.dto.UploadSaveResponse;
import com.lostmiracle.security.SecurityUtils;
import com.lostmiracle.security.UserPrincipal;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/characters/{characterId}/save")
public class SaveController {

    private final SaveService saveService;

    public SaveController(SaveService saveService) {
        this.saveService = saveService;
    }

    @GetMapping
    public ApiResponse<SaveDownloadResponse> download(@PathVariable long characterId) {
        UserPrincipal principal = SecurityUtils.requirePrincipal();
        return ApiResponse.ok(saveService.download(principal.userId(), characterId));
    }

    @PutMapping
    public ApiResponse<UploadSaveResponse> upload(
            @PathVariable long characterId,
            @Valid @RequestBody UploadSaveRequest request
    ) {
        UserPrincipal principal = SecurityUtils.requirePrincipal();
        return ApiResponse.ok(saveService.upload(principal.userId(), characterId, request));
    }
}
