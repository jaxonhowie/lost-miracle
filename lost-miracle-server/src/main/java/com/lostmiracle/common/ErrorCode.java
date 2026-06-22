package com.lostmiracle.common;

public final class ErrorCode {

    public static final int OK = 0;
    public static final int BAD_REQUEST = 40001;
    public static final int UNAUTHORIZED = 40100;
    public static final int FORBIDDEN = 40300;
    public static final int NOT_FOUND = 40400;
    public static final int CONFLICT = 40901;
    public static final int TOO_MANY_REQUESTS = 42900;
    public static final int SERVICE_UNAVAILABLE = 50301;
    public static final int INTERNAL_ERROR = 50000;

    private ErrorCode() {
    }
}
