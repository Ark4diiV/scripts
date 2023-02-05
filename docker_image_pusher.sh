#!/bin/bash
# Help
case "$1" in
  "-h")
    echo 'Usage: ./docker_image_pusher.sh -a <tar archive> -u <url registry>

Options:
  -a      tar.gz archive
  -u      URL registry
  -h      display this help message

Examples:
  ./docker_image_pusher.sh -a k8s.io.tar.gz -u "example.com/uri/"'
    exit 0
    ;;
esac

while getopts "a:u:" opt
do
  case "$opt" in
    a) tar_archive=${OPTARG};;      # Pass file with list of Docker images
    u) url_atregistry=${OPTARG};;   # Output dir
    \?)                             # If no options
      echo "Error: Invalid option -"${OPTARG}"" >&2
      exit 1
      ;;
  esac
done

#If options without arguments
[ -z ${tar_archive} ] || [ -z ${registry} ] && echo "Error: Required argument(s) not provided" >&2 && exit 1

mkdir downloaded_docker_images                                              # Creare dir for downloaded images
tar xvzf ${tar_archive} -C downloaded_docker_images --strip-components=1    # Unarchive tar.gz
cd downloaded_docker_images                                                 # Go to workdir
ls -1 > /tmp/images_list                                                    # Save images list

# Load Docker images to local storage
while read -r list;
do
    docker load -i ${list};
done < /tmp/images_list

docker images | sed '1d' > /tmp/current_docker_images                       # Save list of downloaded Docker images to file

# Tag each Docker image with the appropriate url
while read -r list;
do
    docker tag  $(echo ${list} | awk '{print $3}') \
                $(echo ${registry}$(echo ${list} | awk '{print $1}' | sed 's/.*\/\([^:]*\).*/\1/'):$(echo ${list} | awk '{print $2}'))
    docker push $(echo ${registry}$(echo ${list} | awk '{print $1}' | sed 's/.*\/\([^:]*\).*/\1/'):$(echo ${list} | awk '{print $2}'))
    docker rmi  $(echo ${list} | awk '{print $3}') --force;
done < /tmp/current_docker_images

# Clean up after yourself
rm -rf /tmp/images_list 
rm -rf ../downloaded_docker_images
rm -rf /tmp/current_docker_images
