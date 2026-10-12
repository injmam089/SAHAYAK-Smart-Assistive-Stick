package com.sahayak.backend.common.exception;

import org.springframework.http.HttpStatus;

/**
 * Exception thrown when authentication fails or a token is invalid/expired.
 */
public class UnauthorizedException extends ApiException {

    public UnauthorizedException(String message) {
        super(message, HttpStatus.UNAUTHORIZED);
    }
}
