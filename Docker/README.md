# Task 1.
## Run the image, if the image doesn't exist then install it
docker run --rm -it amazon/aws-cli:2.0.6 command

## create container by a image with name defined
docker container run --name awscli_container -it amazon/aws-cli:2.0.6 command

# Task 3.
## 1. Run a Single Process in Each Container
## 2. Keep Docker Image and Container That Works
## 3. Networking in Containers

## file size of container
docker ps --size

## docker disk usage
docker system df

## Remove unused image 
docker image prune -a

## for more: 
- docker system prune -a (include containers + volumes + networks + images)
- docker volume prune

# Advanced Criteria (for container only, convert image to container)
- docker export awscli_container > awscli.tar 
- cat awscli.tar | docker import - awscliimage:new