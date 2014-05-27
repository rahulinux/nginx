#!/bin/bash
#
# Compile Chrooted Nginx Setup 
#
# Raw Eng DevOps Team <Rahul Patil>


#
## Supported for Ubuntu 12.04 x86_64 
#

#
## Global Variables 
#

chroot_dir="/nginx/"
user="nginx"
install_dir="/opt/nginx/"
logs="info.log"

#
## Functions 
#

info() {

	tput bold
	tput setaf 3 # set color 
	echo 
	echo "${@}"
	echo 
	sleep 2s
	tput sgr 0   # reset color 

}

cmd(){

	tput bold
	tput setaf 4
	echo "${@}"
	sleep 1s 
	eval "${@}"
	tput sgr 0 
}

#
## Setting Up base requirement 
#

info "Setting up base requirement"

cmd "useradd -r ${user}" 
cmd "mkdir ${install_dir}"
cmd "mkdir ${chroot_dir}"

info "Installing Dependencies...."

cmd "apt-get install build-essential git unzip prelink nscd libssl-dev -y"
cmd "apt-get install lua5.1 liblua5.1-0 liblua5.1-0-dev -y"
cmd "ln -s /usr/lib/x86_64-linux-gnu/liblua5.1.so /usr/lib/liblua.so"

info "Downloading Nginx Modules"

cmd cd /usr/local/src/
cmd mkdir nginx_compile 
cmd cd nginx_compile/
cmd wget http://nginx.org/download/nginx-1.4.1.tar.gz
cmd wget http://ftp.cs.stanford.edu/pub/exim/pcre/pcre-8.32.tar.gz
cmd wget https://github.com/simpl/ngx_devel_kit/archive/v0.2.19.tar.gz -o ngx_devel_kit.tar.gz
cmd wget https://github.com/openresty/lua-nginx-module/archive/v0.9.7.tar.gz -o lua-nginx.tar.gz
cmd wget https://github.com/openresty/redis2-nginx-module/archive/v0.11.tar.gz -o redis2-module.tar.gz
cmd git clone https://github.com/agentzh/nginx-eval-module.git

info "Extracting modules.."
xargs -n1 tar -xzvf < <(echo *.tar.gz)

info "Compiling nginx.."
cmd cd nginx-1.4.1/
./configure --prefix="${install_dir}" --user="${user}" \
			--group=nginx --with-http_ssl_module \
			--without-http_scgi_module --without-http_uwsgi_module \
			--without-http_fastcgi_module --with-pcre=../pcre-8.32/ \
			--add-module=../ngx_devel_kit-0.2.19/ \
			--add-module=../lua-nginx-module-0.9.7/ \
			--add-module=../nginx-eval-module/ \
			--add-module=../redis2-nginx-module-0.11/ 

make -j2
make install 

info "Compilation process completed..."

info "Setingup Chroot environment.."
cmd mkdir -p ${chroot_dir}/{etc,dev,var,home,usr,${install_dir},tmp,var/tmp,lib64,lib}
cmd chmod 1777 ${chroot_dir}/{tmp,var/tmp}

info "Create Required Devices in ${chroot_dir}/dev"

cmd mknod -m 0666 ${chroot_dir}/dev/null c 1 3
cmd mknod -m 0666 ${chroot_dir}/dev/random c 1 8
cmd mknod -m 0444 ${chroot_dir}/dev/urandom c 1 9

info "Copy All Nginx Files In Directory"

cmd "cp -farv ${install_dir}/* ${chroot_dir}/${install_dir}/"

info "Copy Required Libs To Jail"

cmd "apt-get -y install libpthread*"
cmd "cp -arv /lib64/* ${chroot_dir}/lib64/"
cmd "cp -arv /lib/* ${chroot_dir}/lib/"

info "Downloading make chroot script"

cmd cd /tmp	
cmd wget http://bash.cyberciti.biz/dl/527.sh.zip
cmd unzip 527.sh.zip
cmd mv 527.sh /usr/bin/n2chroot
cmd chmod +x /usr/bin/n2chroot

cmd n2chroot /opt/nginx/sbin/nginx

info "Copy /etc To Jail"

cmd cp -fv /etc/{group,prelink.cache,services,adjtime,shells,gshadow,shadow,hosts.deny,localtime,nsswitch.conf,nscd.conf,prelink.conf,protocols,hosts,passwd,ld.so.cache,ld.so.conf,resolv.conf,host.conf} ${chroot_dir}/etc
cmd cp -avr /etc/{ld.so.conf.d,prelink.conf.d} ${chroot_dir}/etc

info "Settingup Permissions to ${chroot_dir}"

chown -R ${user}. ${chroot_dir}

info "Testing Nginx.."

cmd "/usr/sbin/chroot ${chroot_dir} ${install_dir}/sbin/nginx -t"
# /usr/sbin/chroot /nginx /opt/nginx/sbin/nginx

info "Configuring Nginx Conf file"
cmd sed -i "s/#user  nobody;/user $user/" ${chroot_dir}/conf/nginx.conf
cmd sed -i '/include       mime.types;/a\    include       conf.d\/\*.conf;' ${chroot_dir}/conf/nginx.conf 
cmd sed -i '/include       mime.types;/a\    underscores_in_headers on;' ${chroot_dir}/conf/nginx.conf 

info "Installing INIT Script for Nginx"
cmd "wget -O /etc/init.d/nginx https://raw.githubusercontent.com/rahulinux/scripts/master/nginx-chroot-init.sh"
cmd chmod +x /etc/init.d/nginx 

info "Process successfully completed"
