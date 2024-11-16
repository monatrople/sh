sysctl -w net.core.rps_sock_flow_entries=65536
cc=$(grep -c processor /proc/cpuinfo)
rfc=$(echo 65536/$cc|bc)
for fileRfc in $(ls /sys/class/net/e*/queues/rx-*/rps_flow_cnt)
do
    echo $rfc > $fileRfc
done

cc=$(grep -c processor /proc/cpuinfo)
c=$(bc -l -q << EOF
a1=l($cc)
a2=l(2)
scale=0
a1/a2
EOF
)
cpus=$(echo $c|awk '{for(i=1;i<$1-1;i++){printf "f"}}')
cpuss=$(echo $c|awk '{for(i=1;i<$1;i++){printf "f"}}')
cpusss=$(echo $c|awk '{for(i=1;i<=$1;i++){printf "f"}}')
cpussss=$(echo $c|awk '{for(i=1;i<=$1+1;i++){printf "f"}}')
for fileRps in $(ls /sys/class/net/e*/queues/rx-*/rps_cpus)
do
    echo $cpus > $fileRps
    echo $cpuss > $fileRps
    echo $cpusss > $fileRps
    echo $cpussss > $fileRps
done
