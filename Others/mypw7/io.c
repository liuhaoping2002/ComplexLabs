#include"lib.h"
int main() {
    int a = getint();
    putint(a);
    float b[10000] = {1, 2};
    int n = getfarray(b);
    putfarray(n+1, b);
    return b[0];
}
