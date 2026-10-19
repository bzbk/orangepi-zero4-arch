#!/bin/sh
cat > /usr/local/bin/arm-linux-gnueabi-gcc <<'WRAP'
#!/bin/sh
exec /usr/bin/arm-linux-gnueabi-gcc "$@" -Wno-error -Wno-error=attributes -Wno-attributes -Wno-error=address-of-packed-member -Wno-address-of-packed-member -Wno-error=array-bounds -Wno-array-bounds -Wno-error=stringop-overflow -Wno-stringop-overflow -Wno-error=maybe-uninitialized -Wno-maybe-uninitialized -fcommon
WRAP
chmod +x /usr/local/bin/arm-linux-gnueabi-gcc
/usr/local/bin/arm-linux-gnueabi-gcc -dumpversion
