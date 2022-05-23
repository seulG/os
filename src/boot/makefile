build/%.bin: %.S
	nasm -I include -f bin $< -o $@

build/%.img: build/%.bin
ifeq ("$(wildcard build/master.img)", "")
	bximage -q -hd=64 -func=create -sectsize=512 -imgmode=flat build/master.img
endif
	dd if=$< of=build/master.img bs=512 count=1 conv=notrunc

build/loader.img: build/mbr.img build/loader.bin
	dd if=build/loader.bin of=build/master.img bs=512 count=4 seek=2 conv=notrunc

%.run: build/%.img
	bochs -q -unlock
	rm -rf bx_enh_dbg.ini

.PHONY:clean
clean:
	rm -rf build/*.bin
	rm -rf build/*.img
	rm -rf build/*.lock
