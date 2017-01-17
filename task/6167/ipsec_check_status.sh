#!/bin/sh

#check l2tp/pptp client status
pptpc_en=`uci get pptpc.main.enabled`
if [ "$pptpc_en" == "1" ]; then
        pptpc_run=`ifconfig | grep ppp1723`
        if [ "$pptpc_run" == "" ]; then
                #echo "restart pptpc" > /etc/kk.log
                /etc/init.d/pptpc restart &
        fi
fi

l2tpc_en=`uci get xl2tpd.main.enabled`
if [ "$l2tpc_en" == "1" ]; then
        l2tpc_run=`ifconfig | grep ppp1701`
        if [ "$l2tpc_run" == "" ]; then
                #echo "restart pptpc" > /etc/kk.log
                /etc/init.d/xl2tpd restart &
                #xl2tpd-control disconnect client
                #xl2tpd-control connect client
        fi
fi

