FROM centos:centos7
RUN yum install epel-release -y && yum install nginx -y
ADD docker/nginx/conf/hello-world.conf /etc/nginx/conf.d/
EXPOSE 80
RUN /bin/bash -c "yum install epel-release python3 python3-devel gcc -y && pip3 install uwsgi && mkdir -p /opt/hello-world/ && python3 -m venv /opt/hello-world/virtualenv && mkdir -p /opt/hello-world/virtualenv/hello-world && mkdir -p /etc/uwsgi/sites/"
ADD hello-world/ /opt/hello-world/virtualenv/hello-world/
ADD docker/hello-world/uwsgi_conf/hello-world.ini /etc/uwsgi/sites/
#RUN useradd uwsgi
#RUN chown -R uwsgi:uwsgi /opt/hello-world/virtualenv/hello-world/
#USER uwsgi
CMD nginx -g "daemon on;" ; uwsgi --ini /etc/uwsgi/sites/hello-world.ini
