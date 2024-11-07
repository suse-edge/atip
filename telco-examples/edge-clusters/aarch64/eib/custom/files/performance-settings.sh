#!/bin/bash

# Script generate to tuning the performance of the system for running Telco Workloads
# This script is intended to be run on a worker node in a Telco Edge Cluster

if [ "`whoami`" != "root" ]; then
        echo root required to run the script
        exit 127
fi

MAX_EXIT_LATENCY=1
input=$(cat /etc/tuned/cpu-partitioning-variables.conf)
total_cores=$(grep -c ^processor /proc/cpuinfo)
cpus=$(echo "$input" | awk -F'=' '{print $2}')

expand_ranges() {
    echo "$1" | awk -v RS=',' '
    {
        if ($1 ~ /-/) {
            split($1, range, "-")
            for (i = range[1]; i <= range[2]; i++) {
                printf i (i==range[2] ? "" : " ")
            }
        } else {
            printf $1
        }
        printf (NR == NR ? " " : "")
    }' | sed 's/ $//'
}

ISOLATED_CPUS=$(expand_ranges "$cpus")
all_cores=$(seq 0 $((total_cores-1)))
isolated_set=$(echo $ISOLATED_CPUS | tr ',' '\n') # Convert to newline separated list
HK_CPUS=""

for core in $all_cores; do
    if ! echo "$isolated_set" | grep -q "^$core$"; then
        HK_CPUS+="$core "
    fi
done

HK_CPUS=$(echo "$HK_CPUS" | sed 's/ $//')

set_cpufreq_performance() {
	echo Configure: CpuFreq performance
	cpupower frequency-set -g performance | grep -v "Setting cpu:"
	cpupower set -b 0
}

unset_timer_migration() {
	echo Configure: Disable Timer migration
	sysctl kernel.timer_migration=0
}

migrate_kdaemons_hk() {
	echo Configure: Migrate kthreads to HK
	for NODE in `ls -1 -d /sys/devices/system/node/node* | sed -e 's/.*node//'`; do
		for KTHREAD in kswapd$NODE kcompactd$NODE ; do
			PID_KTHREAD=`pidof $KTHREAD`
			[ "$PID_KTHREAD" = "" ] && PID_KTHREAD=`pidof -w $KTHREAD`
			if [ "$PID_KTHREAD" = "" ]; then
				echo "WARNING: Unable to identify PID of $KTHREAD"
				continue
			fi
			taskset -pc `echo $HK_CPUS | tr ' ' ','` $PID_KTHREAD
		done
	done
}

set_isolatecpu_latency() {
	echo Configure: IsolCpus latency requirements
	cat /proc/cmdline  | tr ' ' '\n' | grep -q ^idle=poll
	if [ $? -eq 0 ]; then
		echo "WARNING: Using idle=poll as a kernel paramter makes per-cpu pm qos redundant"
		return
	fi

	for CPU in $ISOLATED_CPUS; do
		SYSFS_PARAM="/sys/devices/system/cpu/cpu$CPU/power/pm_qos_resume_latency_us"
		if [ ! -e $SYSFS_PARAM ]; then
			echo "WARNING: Unable to set PM QOS max latency for CPU $CPU\n"
			continue
		fi
		echo $MAX_EXIT_LATENCY > $SYSFS_PARAM
		echo "Set PM QOS maximum resume latency on CPU $CPU to ${MAX_EXIT_LATENCY}us"
	done
}

delay_vmstat_updates() {
	echo Configure: Delay vmstat updates
	sysctl -w vm.stat_interval=300
}

set_cpufreq_performance
unset_timer_migration
migrate_kdaemons_hk
set_isolatecpu_latency
delay_vmstat_updates