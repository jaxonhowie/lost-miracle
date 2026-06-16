package com.lostmiracle.module.admin;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.lostmiracle.module.admin.entity.GmAuditLogEntity;
import com.lostmiracle.module.admin.mapper.GmAuditLogMapper;
import org.springframework.stereotype.Service;

import java.util.Map;

@Service
public class GmAuditService {

    private final GmAuditLogMapper gmAuditLogMapper;
    private final ObjectMapper objectMapper;

    public GmAuditService(GmAuditLogMapper gmAuditLogMapper, ObjectMapper objectMapper) {
        this.gmAuditLogMapper = gmAuditLogMapper;
        this.objectMapper = objectMapper;
    }

    public void log(long gmAccountId, String action, String targetType, String targetId, Map<String, Object> detail, String ip) {
        GmAuditLogEntity entity = new GmAuditLogEntity();
        entity.setGmAccountId(gmAccountId);
        entity.setAction(action);
        entity.setTargetType(targetType);
        entity.setTargetId(targetId);
        entity.setDetailJson(toJson(detail));
        entity.setIp(ip);
        gmAuditLogMapper.insert(entity);
    }

    private String toJson(Map<String, Object> detail) {
        if (detail == null || detail.isEmpty()) {
            return null;
        }
        try {
            return objectMapper.writeValueAsString(detail);
        } catch (JsonProcessingException e) {
            return "{\"error\":\"detail serialization failed\"}";
        }
    }
}
