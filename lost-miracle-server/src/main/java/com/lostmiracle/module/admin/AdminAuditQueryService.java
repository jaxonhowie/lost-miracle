package com.lostmiracle.module.admin;

import com.lostmiracle.module.admin.dto.GmAuditLogListResponse;
import com.lostmiracle.module.admin.dto.GmAuditLogResponse;
import com.lostmiracle.module.admin.entity.GmAuditLogEntity;
import com.lostmiracle.module.admin.mapper.GmAuditLogMapper;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class AdminAuditQueryService {

    private final GmAuditLogMapper gmAuditLogMapper;

    public AdminAuditQueryService(GmAuditLogMapper gmAuditLogMapper) {
        this.gmAuditLogMapper = gmAuditLogMapper;
    }

    public GmAuditLogListResponse listRecent(int page, int pageSize) {
        int safePage = Math.max(page, 1);
        int safeSize = Math.min(Math.max(pageSize, 1), 100);
        int offset = (safePage - 1) * safeSize;
        List<GmAuditLogResponse> items = gmAuditLogMapper.selectRecent(safeSize, offset).stream()
                .map(this::toResponse)
                .toList();
        return new GmAuditLogListResponse(items, safePage, safeSize);
    }

    private GmAuditLogResponse toResponse(GmAuditLogEntity entity) {
        return new GmAuditLogResponse(
                entity.getId(),
                entity.getGmAccountId(),
                entity.getAction(),
                entity.getTargetType(),
                entity.getTargetId(),
                entity.getDetailJson(),
                entity.getIp(),
                entity.getCreatedAt()
        );
    }
}
