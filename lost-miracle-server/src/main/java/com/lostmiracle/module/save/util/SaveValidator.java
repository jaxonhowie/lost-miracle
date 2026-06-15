package com.lostmiracle.module.save.util;

import com.lostmiracle.common.BusinessException;
import com.lostmiracle.common.ErrorCode;

import java.util.List;
import java.util.Map;

public final class SaveValidator {

    private static final int MAX_INVENTORY_SIZE = 200;

    private SaveValidator() {
    }

    @SuppressWarnings("unchecked")
    public static void validate(Map<String, Object> save) {
        Object playerObj = save.get("player");
        if (!(playerObj instanceof Map<?, ?> playerMap)) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "missing player data");
        }
        Map<String, Object> player = (Map<String, Object>) playerMap;
        if (!player.containsKey("level")) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "missing player.level");
        }

        Object inventoryObj = save.get("inventory");
        if (!(inventoryObj instanceof List<?> inventory)) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "missing inventory");
        }
        if (inventory.size() > MAX_INVENTORY_SIZE) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "inventory too large");
        }
    }
}
