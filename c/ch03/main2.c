#include <stdio.h>

int call();

int main()
{
    long d = call();
    printf("乘积=%ld\n", d);
    return 0;
}