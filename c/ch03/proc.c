long proc(long x1, long *xp1, int x2, int *xp2, short x3, short *xp3, char x4, char *xp4)
{
    *xp1 = 2 * x1;
    *xp2 = 2 * x2;
    *xp3 = 2 * x3;
    *xp4 = 2 * x4;
    return *xp1;
}

long call()
{
    long x1 = 1;
    int x2 = 2;
    short x3 = 3;
    char x4 = 4;
    long r = proc(x1, &x1, x2, &x2, x3, &x3, x4, &x4);
    return (x1 + x2) * (x3 - x4);
}