// gcc -I lib/kernel
#include "print.h"
void main(void) {
    put_char('k');
    put_char('e');
    put_char('r');
    put_char('n');
    put_char('e');
    put_char('l');
    put_char('\n');
    put_char('1');
    put_char('2');
    put_char('\b');
    put_char('3');
    put_char('\n');
    unsigned int i = 0;
    for(; i < 10; i++)
        put_char('0' + i);
    while(1);
}