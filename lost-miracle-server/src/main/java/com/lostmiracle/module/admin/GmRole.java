package com.lostmiracle.module.admin;

import com.lostmiracle.common.BusinessException;
import com.lostmiracle.common.ErrorCode;

public enum GmRole {
    viewer,
    operator,
    super_;

    public static GmRole fromString(String value) {
        if (value == null || value.isBlank()) {
            throw new BusinessException(ErrorCode.INTERNAL_ERROR, "invalid gm role");
        }
        if ("super".equals(value)) {
            return super_;
        }
        try {
            return GmRole.valueOf(value);
        } catch (IllegalArgumentException e) {
            throw new BusinessException(ErrorCode.INTERNAL_ERROR, "invalid gm role");
        }
    }

    public String toDbValue() {
        return this == super_ ? "super" : name();
    }

    public boolean atLeast(GmRole required) {
        return ordinal() >= required.ordinal();
    }
}
