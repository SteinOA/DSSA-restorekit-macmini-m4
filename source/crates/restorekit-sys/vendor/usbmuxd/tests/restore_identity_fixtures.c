/* Pure fixtures: compile/run separately; no libusb linkage or hardware access. */
#include <stdio.h>
#include "../src/restore_identity.h"
#define CHECK(test) do { if (!(test)) { fprintf(stderr,"FAIL line %d: %s\n",__LINE__,#test); return 1; } } while (0)
static size_t descriptor(const char *text, unsigned char *out)
{
    size_t count = strlen(text);
    out[0] = (unsigned char)(2 + count*2); out[1] = 3;
    for (size_t i=0;i<count;i++) { out[2+i*2]=(unsigned char)text[i]; out[3+i*2]=0; }
    return 2+count*2;
}
int main(void)
{
    unsigned char data[255]; char serial[128]; size_t count;
    count=descriptor("00008132001808291EA2401C",data);
    CHECK(!rk_verify_restore_response(1,data,count,serial,sizeof(serial)));
    CHECK(!strcmp(serial,"00008132001808291EA2401C"));
    count=descriptor("00008132-001808291EA2401C",data);
    CHECK(!rk_verify_restore_response(1,data,count,serial,sizeof(serial)));
    count=descriptor("00008132-001808291ea2401c",data);
    CHECK(!rk_verify_restore_response(1,data,count,serial,sizeof(serial)));
    count=descriptor("00008132-001808291EA2401D",data);
    CHECK(!strcmp(rk_verify_restore_response(1,data,count,serial,sizeof(serial)),"authorized-identity-mismatch"));
    CHECK(!rk_authorized_restore_serial("00008132--001808291EA2401C"));
    CHECK(!rk_authorized_restore_serial("00008133-001808291EA2401C"));
    CHECK(!rk_authorized_restore_serial("00008132-001808291EA2401C "));
    CHECK(!strcmp(rk_verify_restore_response(0,NULL,0,serial,sizeof(serial)),"usb-transfer-not-completed"));
    CHECK(!strcmp(rk_verify_restore_response(1,data,1,serial,sizeof(serial)),"short-or-oversized-descriptor"));
    count=descriptor("00008132001808291EA2401C",data);
    CHECK(rk_verify_restore_response(1,data,count-2,serial,sizeof(serial))!=NULL);
    data[1]=2; CHECK(rk_verify_restore_response(1,data,count,serial,sizeof(serial))!=NULL);
    count=descriptor("00008132001808291EA2401C",data);
    data[3]=1; CHECK(rk_verify_restore_response(1,data,count,serial,sizeof(serial))!=NULL);
    count=descriptor("00008132001808291EA2401C",data);
    data[2]=0; CHECK(rk_verify_restore_response(1,data,count,serial,sizeof(serial))!=NULL);
    CHECK(rk_decode_restore_serial(data,count,serial,1)!=NULL);
    uint16_t language=0;
    unsigned char english[]={4,3,9,4};
    unsigned char norwegian[]={4,3,0x14,4};
    unsigned char multiple[]={6,3,0x14,4,9,4};
    unsigned char zero[]={4,3,0,0};
    CHECK(!rk_advertised_language(english,sizeof(english),&language)&&language==0x0409);
    CHECK(!rk_advertised_language(norwegian,sizeof(norwegian),&language)&&language==0x0414);
    CHECK(!rk_advertised_language(multiple,sizeof(multiple),&language)&&language==0x0409);
    CHECK(rk_advertised_language(zero,sizeof(zero),&language)!=NULL);
    CHECK(rk_advertised_language(english,3,&language)!=NULL);
    CHECK(rk_advertised_language(english,2,&language)!=NULL);
    puts("restore identity fixtures passed (pure data; no USB access)");
    return 0;
}
