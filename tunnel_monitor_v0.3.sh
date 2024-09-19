#!/bin/bash
CYAN='\033[0;36m'
NC='\033[0m' # No Color
while [[ true ]]
do
	tunnel_pids=($(ss -ntlp | grep -Po "ssh\",pid=\d+,fd=5" | grep -Po "\d+," | cut -d',' -f1 | sort -u))
	socket_pids=($(ss -ntlp | grep -Po "ssh\",pid=\d+,fd=\d+\)" | grep -Pv "fd=[45]\)" | grep -Po "\d+," | cut -d',' -f1 | sort -u))	
	# get tunnels
	tunnel_list=()
	i=0
	for item in ${tunnel_pids[*]}; do
		process=$(ps -ef | grep -P "${item}" | grep -Po "ssh .*")
		ssh=$(echo $process | grep -Po "ssh (\w+@)?([a-zA-Z]\w+|[\d\.]+) (-p ?\d+)?")

		# formatting for source to dest port
		fwd_field=$(echo $process | grep -Po "\-[LR] ?\d+:([\d.]+|\w+):\d+" | cut -d" " -f2-)
		tunnel_list[${i}]=$(echo -e "${process} - PID ${item}")
		if [[ -n $fwd_field ]]; then
			srcip="127.0.0.1"
			srcport=$(echo ${fwd_field} | cut -d":" -f1)
			dstip=$(echo ${fwd_field} | cut -d":" -f2)
			dstport=$(echo ${fwd_field} | cut -d":" -f3)
			
			tunnel_list[$[${i} + 1 ]]=$(echo -e "%${srcip}:${srcport} --> ${dstip}:${dstport}")
			i=$[ $i + 2 ]
		elif [[ -n $(echo $process | grep -Po "\-\w*D\w* ?9050") ]]; then
			tunnel_list[$[${i} + 1 ]]=$(echo -e "%127.0.0.1:9050 --> DYNAMIC")
			i=$[ $i + 2 ]
		fi	
		fwd_field=""
	done

	# get master sockets and forwards
	socket_list=()
	i=0
	for item in ${socket_pids[*]}; do
		# get master socket command
		ms=$(ps -ef | grep -P "${item}" | grep -Po "ssh .*")
		socket_list[${i}]="$ms - PID ${item}"
		i=$[ $i + 1 ]
		
		# finds all local ports being forwarded via this master socket
		forward_ports=$(ss -ntlp | grep "pid=${item}" | grep -Po "127.0.0.1:\d+" | cut -d":" -f2 | sed -e 's/^/%/g')
		
		# finds the master socket file
		socket_file=$(echo $ms | grep -Po '\-\w* [/\w]+' | cut -d" " -f2)
		#echo "file ${socket_file}"
		
		# iterates through all forward ports
		z=2 # counting var
		while [[ true ]]; do
			search_port=$(echo $forward_ports | cut -d"%" -f${z})
			
			# checks if there are no further ports to search for
			if [[ -z $search_port ]]; then
				break
			fi

			# grabs the port forward section of the command I.E: 1111:127.0.0.1:4444
			fwd_field=$(ps -ef | grep -Po "ssh .* -[LR] ?${search_port}?:.*" | grep -Po "\d+:.*")

			if [[ -n $fwd_field ]]; then
				srcip="127.0.0.1"
				srcport=$(echo ${fwd_field} | cut -d":" -f1)
				dstip=$(echo ${fwd_field} | cut -d":" -f2)
				dstport=$(echo ${fwd_field} | cut -d":" -f3)

				# output formatting
				socket_list[${i}]="%${srcip}:${srcport} --> ${dstip}:${dstport}"

			elif [[ $search_port -eq 9050 ]]; then
				srcip="127.0.0.1"
				srcport="9050"
				
				# output formatting
                                socket_list[${i}]="%${srcip}:${srcport} --> DYNAMIC"
                                i=$[ $i + 1 ]
			else
				socket_list[${i}]="%127.0.0.1:${search_port} --> UNK"
			fi
			i=$[ $i + 1 ]
			z=$[ $z + 1 ]
		done
	done
	
	# all ssh sessions
	ssh_list=()
	ssh_sessions=$(ss -ntp | grep "ssh" | grep -Po "(\d{1,3}\.){3}\d{1,3}:\d+ .*pid=\d+" | sed -e 's/^/%/g')
	i=0
	z=2
	while [[ true ]]; do
		if [[ -z $(echo ${ssh_sessions} | cut -d"%" -f${z}) ]]; then
			break
		fi
		session=$(echo ${ssh_sessions} | cut -d"%" -f${z})
		src=$(echo ${session} | grep -Po "^[\d.]+:\d+")
		dst=$(echo ${session} | grep -Po " [\d.]+:\d+ ")
		pid=$(echo ${session} | grep -Po "pid=\d+" | cut -d"=" -f2)

		ssh_list[${i}]="${src} --> ${dst} - PID ${pid}"
		i=$[ $i + 1 ]
		z=$[ $z + 1 ]
	done

	# PRINT BLOCK
	clear
	echo "---------- TUNNEL MONITOR V0.3 ----------"
	echo -e "-------- Written by LCpl Nelson ---------\n"
	# print tunnels
	echo -e "Traditional Tunnels: ${CYAN}"
	for ((i = 0 ; i < ${#tunnel_list[@]} ; i++)); do
		echo ${tunnel_list[${i}]} | sed -e 's/%/\t/g'
	done
	echo -e "${NC}"

	# print master sockets and forwards
	echo -e "Master sockets and forwards: ${CYAN}"
	for ((i = 0 ; i < ${#socket_list[@]} ; i++)); do
		echo ${socket_list[${i}]} | sed -e 's/%/\t/g'
	done
	echo -e "${NC}"

	# print all ssh sessions
	echo -e "All SSH sessions: ${CYAN}"
	for ((i = 0 ; i < ${#ssh_list[@]} ; i++)); do
		echo ${ssh_list[${i}]}
	done
	echo -e "${NC}"

	sleep 1
done
