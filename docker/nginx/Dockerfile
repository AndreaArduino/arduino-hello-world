FROM centos:centos7
RUN yum install epel-release -y && yum install nginx -y
ADD docker/nginx/conf/hello-world.conf /etc/nginx/conf.d/
EXPOSE 80
CMD nginx -g "daemon off;"
