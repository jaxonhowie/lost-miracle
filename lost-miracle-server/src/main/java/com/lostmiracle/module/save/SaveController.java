package com.lostmiracle.module.save;

import com.lostmiracle.common.ApiResponse;
import com.lostmiracle.module.save.dto.SaveDownloadResponse;
import com.lostmiracle.module.save.dto.UploadSaveRequest;
import com.lostmiracle.module.save.dto.UploadSaveResponse;
import com.lostmiracle.security.SecurityUtils;
import com.lostmiracle.security.UserPrincipal;
import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/characters/{characterId}/save")
public class SaveController {

    private static final Logger log = LoggerFactory.getLogger(SaveController.class);

    private final SaveService saveService;

    public SaveController(SaveService saveService) {
        this.saveService = saveService;
    }

    @GetMapping
    public ApiResponse<SaveDownloadResponse> download(@PathVariable long characterId) {
        UserPrincipal principal = SecurityUtils.requirePrincipal();
        log.info("save download request userId={} characterId={}", principal.userId(), characterId);
        SaveDownloadResponse response = saveService.download(principal.userId(), characterId);
        log.info("save download ok userId={} characterId={} version={}", principal.userId(), characterId, response.saveVersion());
        return ApiResponse.ok(response);
    }

    @PutMapping
    public ApiResponse<UploadSaveResponse> upload(
            @PathVariable long characterId,
            @Valid @RequestBody UploadSaveRequest request
    ) {
        UserPrincipal principal = SecurityUtils.requirePrincipal();
        log.info(
                "save upload request userId={} characterId={} clientVersion={} force={} clientUpdatedAt={}",
                principal.userId(),
                characterId,
                request.saveVersion(),
                request.force(),
                request.clientUpdatedAt()
        );
        UploadSaveResponse response = saveService.upload(principal.userId(), characterId, request);
        log.info(
                "save upload ok userId={} characterId={} newVersion={} powerScore={}",
                principal.userId(),
                characterId,
                response.saveVersion(),
                response.powerScore()
        );
        return ApiResponse.ok(response);
    }
}
