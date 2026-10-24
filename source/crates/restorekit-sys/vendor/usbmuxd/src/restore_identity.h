#ifndef RK_RESTORE_IDENTITY_H
#define RK_RESTORE_IDENTITY_H
#include <stddef.h>
#include <stdint.h>
#include <string.h>

/* Pure descriptor parsing: no USB access, allocation, or locale-dependent rules. */
static const char *rk_string_shape(const unsigned char *data, size_t actual)
{
    if (!data || actual < 2 || actual > 255) return "short-or-oversized-descriptor";
    if (data[1] != 3) return "wrong-descriptor-type";
    if (data[0] != actual || (actual & 1)) return "invalid-descriptor-length";
    return NULL;
}

static const char *rk_advertised_language(const unsigned char *data, size_t actual, uint16_t *language)
{
    const char *error = rk_string_shape(data, actual);
    if (error) return error;
    if (actual < 4) return "empty-language-list";
    *language = 0;
    for (size_t i = 2; i < actual; i += 2) {
        uint16_t item = (uint16_t)(data[i] | ((uint16_t)data[i+1] << 8));
        if (!item) return "invalid-zero-language";
        if (!*language || item == 0x0409) *language = item;
    }
    return NULL;
}

static const char *rk_decode_restore_serial(const unsigned char *data, size_t actual, char *serial, size_t capacity)
{
    if (!serial || !capacity) return "missing-output-buffer";
    serial[0] = '\0';
    const char *error = rk_string_shape(data, actual);
    if (error) return error;
    size_t count = (actual - 2) / 2;
    if (count >= capacity) return "serial-too-long";
    for (size_t i = 0; i < count; i++) {
        unsigned char low = data[2 + i*2], high = data[3 + i*2];
        if (high || !low || low > 0x7f) { serial[0] = '\0'; return "non-ascii-or-nul-serial"; }
        serial[i] = (char)low;
    }
    serial[count] = '\0';
    return NULL;
}

static int rk_authorized_restore_serial(const char *serial)
{
    static const char expected[] = "00008132001808291EA2401C";
    size_t length = strlen(serial), source = 0;
    if (length != 24 && length != 25) return 0;
    for (size_t i = 0; i < 24; i++) {
        if (i == 8 && length == 25) { if (serial[source++] != '-') return 0; }
        unsigned char ch = (unsigned char)serial[source++];
        if (ch >= 'a' && ch <= 'f') ch = (unsigned char)(ch - 'a' + 'A');
        if (ch != (unsigned char)expected[i]) return 0;
    }
    return source == length;
}

static const char *rk_verify_restore_response(int completed, const unsigned char *data, size_t actual, char *serial, size_t capacity)
{
    if (!serial || !capacity) return "missing-output-buffer";
    serial[0] = '\0';
    if (!completed) return "usb-transfer-not-completed";
    const char *error = rk_decode_restore_serial(data, actual, serial, capacity);
    if (error) return error;
    return rk_authorized_restore_serial(serial) ? NULL : "authorized-identity-mismatch";
}
#endif
