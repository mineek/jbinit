
# .PHONY: *

all: ramdisk.dmg

jbinit:
	xcrun -sdk iphoneos clang -e__dyld_start -Wl,-dylinker -Wl,-dylinker_install_name,/usr/lib/dyld -nostdlib -static -Wl,-fatal_warnings -Wl,-dead_strip -Wl,-Z --target=arm64-apple-ios12.0 -std=gnu17 -flto -ffreestanding -U__nonnull -nostdlibinc -fno-stack-protector jbinit.c printf.c -o jbinit
	mv jbinit com.apple.dyld
	ldid -S com.apple.dyld
	mv com.apple.dyld jbinit

launchd:
	xcrun -sdk iphoneos clang -arch arm64 launchd.m -o launchd -fmodules -fobjc-arc
	ldid -Sent.xml launchd

jb.dylib:
	xcrun -sdk iphoneos clang -arch arm64 -shared jb.c -o jb.dylib
	ldid -S jb.dylib

ramdisk.dmg: jbinit launchd jb.dylib
	mkdir -p ramdisk
	mkdir -p ramdisk/dev
	mkdir -p ramdisk/sbin
	cp launchd ramdisk/sbin/launchd
	mkdir -p ramdisk/usr/lib
	cp jbinit ramdisk/usr/lib/dyld
	cp jb.dylib ramdisk/jb.dylib
	mkdir -p ramdisk/palera1n
	cp tar ramdisk/palera1n/tar
	cp wget ramdisk/palera1n/wget
	hdiutil create -size 8m -layout NONE -format UDRW -srcfolder ./ramdisk -fs HFS+ ./ramdisk.dmg
#	img4 -i ramdisk.dmg -o ramdisk.img4 -A -T rdsk -M IM4M

rootfs: launchd launchd_payload jb.dylib
	mkdir -p rootfs
	mkdir -p rootfs/jbin
	mkdir -p rootfs/palera1n
	cp tar rootfs/palera1n/tar
	cp wget rootfs/palera1n/wget
	cp launchd rootfs/palera1n/jbloader
	cp launchd_payload rootfs/jbin/launchd
	cp jb.dylib rootfs/jbin/jb.dylib
	cd rootfs && zip -r ../rootfs.zip . && cd ..

launchd_payload: launchd
	xcrun -sdk iphoneos clang -arch arm64 launchd_hook.m -o launchd_payload
	ldid -Sent.xml launchd_payload

clean:
	rm -f jbinit
	rm -f launchd
	rm -f jb.dylib
	rm -f ramdisk.dmg
	rm -rf ramdisk
	rm -f rootfs.zip
	rm -rf rootfs
	rm -f launchd_payload
