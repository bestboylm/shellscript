#!/bin/bash
# Day 6
# Author: Aaron
# Description: The sum of memory occupied by all processes in the statistical system
# 正确的方法是累加 /proc/[1-9]*/smaps 中的 Pss 。/proc/<pid>/smaps 包含了进程的每一个内存映射的统计值，
# 详见proc(5)的手册页。Pss(Proportional Set Size)把共享内存的Rss进行了平均分摊，比如某一块100MB的内存被10个进程共享，
# 那么每个进程就摊到10MB。这样，累加Pss就不会导致共享内存被重复计算了。

grep Pss /proc/[1-9]*/smaps | awk '{total+=$2}; END {print total/1024"MB"}'