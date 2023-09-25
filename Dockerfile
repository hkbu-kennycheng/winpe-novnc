FROM alpine

RUN apk update && apk add --no-cache curl wget unzip git bash python3 py3-pip \
    qemu-img qemu-system-x86_64 ovmf qemu-modules swtpm

RUN mkdir /images && cd /images && \
    wget https://github.com/kholia/OSX-KVM/raw/master/OVMF_CODE.fd && \
    wget https://github.com/kholia/OSX-KVM/raw/master/OVMF_VARS.fd && \
    wget https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso && \
    wget https://www.hirensbootcd.org/files/HBCD_PE_x64.iso

RUN qemu-img create -f qcow2 /images/disk1.qcow2 100G && \
    qemu-img create -f qcow2 /images/disk2.qcow2 50G

RUN git clone --depth=1 --recursive https://github.com/novnc/noVNC /novnc

EXPOSE 6080

CMD mkdir /tmp/mytpm1 && \
    swtpm socket --tpmstate dir=/tmp/mytpm1 \
    --ctrl type=unixio,path=/tmp/mytpm1/swtpm-sock \
    --tpm2 \
    --log level=20 & \
    qemu-system-x86_64 \
    -m 16G -smp 8 \
    -machine q35 \
    -usb -device usb-tablet -device virtio-gpu \
    -netdev user,id=n0,hostfwd=tcp::3389-:3389 -device rtl8139,netdev=n0 \
    -chardev socket,id=chrtpm,path=/tmp/mytpm1/swtpm-sock \
    -tpmdev emulator,id=tpm0,chardev=chrtpm \
    -device tpm-tis,tpmdev=tpm0 \
    -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE.fd \
    -drive if=pflash,format=raw,file=/images/OVMF_VARS.fd \
    -drive file=/images/HBCD_PE_x64.iso,if=ide,index=0,media=cdrom \
    -cdrom /images/virtio-win.iso -vnc :0 -k en-us \
    -drive file=/images/disk1.qcow2,if=ide,index=3,media=disk \
    -drive file=/images/disk2.qcow2,if=ide,index=4,media=disk \
    -monitor stdio "$@" & \
    /novnc/utils/novnc_proxy --vnc localhost:5900
