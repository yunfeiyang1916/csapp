float float_mov(float v1, float *src, float *dst)
{
    float v2 = *src;
    *dst = v1;
    return v2;
}

double f1(int x, double y, long z)
{
    int x1 = x;
    double y1 = y;
    long z1 = z;
    return y1;
}

double f2(double y, int x, long z)
{
    int x1 = x;
    double y1 = y;
    long z1 = z;
    return y1;
}

double f3(float x, double *y, long *z)
{
    int x1 = x;
    double y1 = *y;
    long z1 = *z;
    return y1;
}