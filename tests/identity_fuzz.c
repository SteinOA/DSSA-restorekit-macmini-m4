#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include "../src/restore_identity.h"
static uint32_t state;
static uint32_t next_random(void) { state ^= state << 13; state ^= state >> 17; state ^= state << 5; return state; }
static int oracle(const unsigned char *p, size_t n, size_t capacity) {
    const char expected[]="00008132001808291EA2401C";
    if(n<2 || n>255 || p[0]!=n || p[1]!=3 || (n&1)) return 0;
    size_t count=(n-2)/2;
    if(count>=capacity || (count!=24 && count!=25)) return 0;
    size_t k=0;
    for(size_t i=0;i<count;i++) {
        unsigned char c=p[2+i*2];
        if(p[3+i*2] || !c || c>127) return 0;
        if(count==25 && i==8) { if(c!='-') return 0; continue; }
        if(c>='a' && c<='f') c=(unsigned char)(c-32);
        if(c!=(unsigned char)expected[k++]) return 0;
    }
    return k==24;
}
static size_t make_valid(unsigned char *p, int dashed) {
    const char *text=dashed?"00008132-001808291EA2401C":"00008132001808291EA2401C";
    size_t n=strlen(text); p[0]=(unsigned char)(2+2*n); p[1]=3;
    for(size_t i=0;i<n;i++) { p[2+2*i]=(unsigned char)text[i]; p[3+2*i]=0; }
    return 2+2*n;
}
int main(int argc, char **argv) {
    state=argc>1?(uint32_t)strtoul(argv[1],NULL,10):123456789u;
    if(!state) state=1;
    uint32_t seed=state;
    for(unsigned iteration=0;iteration<100000;iteration++) {
        unsigned char data[256], output[132];
        for(size_t i=0;i<sizeof(data);i++) data[i]=(unsigned char)next_random();
        size_t actual=next_random()%256, capacity=next_random()%129;
        if(iteration%4==0) {
            actual=make_valid(data,(int)(next_random()%2));
            unsigned mutations=next_random()%4;
            for(unsigned j=0;j<mutations;j++) data[next_random()%actual]^=(unsigned char)(1u<<(next_random()%8));
        }
        memset(output,0xA5,sizeof(output));
        int completed=(int)(next_random()%5!=0);
        const char *error=rk_verify_restore_response(completed,data,actual,(char*)&output[1],capacity);
        int accepted=error==NULL;
        int expected=completed && oracle(data,actual,capacity);
        if(accepted!=expected || output[0]!=0xA5 || output[capacity+1]!=0xA5) {
            fprintf(stderr,"FAIL seed=%u iteration=%u actual=%zu capacity=%zu accepted=%d expected=%d\n",seed,iteration,actual,capacity,accepted,expected); return 1;
        }
        uint16_t language=0;
        const char *lang_error=rk_advertised_language(data,actual,&language);
        if(!lang_error && (!language || actual<4 || actual>255 || data[0]!=actual || data[1]!=3 || (actual&1))) return 2;
    }
    printf("PASS seed=%u cases=100000 pure-data malformed fuzz and identity oracle\n",seed);
    return 0;
}
