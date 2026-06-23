package com.lostmiracle.module.mail;

import java.util.Map;
import java.util.Set;

/**
 * 邮件附件的共享策略：白名单和数值上限。
 * AdminMailService（发送时校验）和 MailService（领取时防御）共同引用。
 */
public final class MailAttachmentPolicy {

    public static final Set<String> ALLOWED_KEYS = Set.of(
            "gold", "enhance_stone", "blessed_enhance_stone",
            "jewelry_enhance_stone", "blessed_jewelry_enhance_stone",
            "health_potion"
    );

    /** 每封邮件单个 key 的数值上限 */
    public static final Map<String, Integer> CAPS = Map.of(
            "gold", 1_000_000,
            "enhance_stone", 9_999,
            "blessed_enhance_stone", 999,
            "jewelry_enhance_stone", 9_999,
            "blessed_jewelry_enhance_stone", 999,
            "health_potion", 999
    );

    private MailAttachmentPolicy() {
    }
}
