# Use the light version of the image that contains just the latest binary
FROM hashicorp/terraform


# Install Bash Pip

RUN apk update && apk add ca-certificates && rm -rf /var/cache/apk/*


# The app folder will contain all our files
WORKDIR /app

# Put all your configration files in the same folder as the Dockerfile.
# The COPY instruction copies files/folders from the local machine and adds it to the filesystem of the container. 
# The following command copies all files from the current folder (the folder in which Dockerfile resides) into a folder called app in the container.

COPY . /app

# Initalize terraform with local settings and data
RUN ["terraform", "init"]

# Plan and execute the configurations
CMD [ "apply"]