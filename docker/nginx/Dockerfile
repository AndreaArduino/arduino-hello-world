FROM centos:centos7
RUN yum install epel-release -y && yum install nginx -y
ADD docker/nginx/conf/hello-world.conf /etc/nginx/conf.d/
ADD docker/nginx/conf/nginx.conf /etc/nginx/
EXPOSE 80
CMD nginx -g "daemon off;"
