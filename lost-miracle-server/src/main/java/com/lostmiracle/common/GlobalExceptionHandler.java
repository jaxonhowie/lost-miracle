package com.lostmiracle.common;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.redis.RedisConnectionFailureException;
import org.springframework.http.HttpStatus;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.servlet.resource.NoResourceFoundException;

import java.util.stream.Collectors;

@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(BusinessException.class)
    @ResponseStatus(HttpStatus.OK)
    public ApiResponse<Object> handleBusiness(BusinessException ex) {
        if (ex.getCode() >= ErrorCode.INTERNAL_ERROR) {
            log.error("business error code={} message={}", ex.getCode(), ex.getMessage(), ex);
        } else {
            log.warn("business error code={} message={} data={}", ex.getCode(), ex.getMessage(), ex.getData());
        }
        return ApiResponse.fail(ex.getCode(), ex.getMessage(), ex.getData());
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    @ResponseStatus(HttpStatus.OK)
    public ApiResponse<Void> handleValidation(MethodArgumentNotValidException ex) {
        String message = ex.getBindingResult().getFieldErrors().stream()
                .map(FieldError::getDefaultMessage)
                .collect(Collectors.joining("; "));
        log.warn("request validation failed: {}", message);
        return ApiResponse.fail(ErrorCode.BAD_REQUEST, message);
    }

    @ExceptionHandler(RedisConnectionFailureException.class)
    @ResponseStatus(HttpStatus.OK)
    public ApiResponse<Void> handleRedis(RedisConnectionFailureException ex) {
        log.error("redis connection failed", ex);
        return ApiResponse.fail(ErrorCode.INTERNAL_ERROR, "redis unavailable");
    }

    @ExceptionHandler(NoResourceFoundException.class)
    @ResponseStatus(HttpStatus.OK)
    public ApiResponse<Void> handleNoResource(NoResourceFoundException ex) {
        log.warn("api not found: {} {}", ex.getHttpMethod(), ex.getResourcePath());
        return ApiResponse.fail(ErrorCode.NOT_FOUND, "api not found");
    }

    @ExceptionHandler(Exception.class)
    @ResponseStatus(HttpStatus.OK)
    public ApiResponse<Void> handleGeneric(Exception ex) {
        log.error("unhandled exception", ex);
        return ApiResponse.fail(ErrorCode.INTERNAL_ERROR, "internal server error");
    }
}
