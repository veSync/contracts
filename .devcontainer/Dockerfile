# Use an official Node runtime as a parent image
FROM node:18

# Install curl and other dependencies
RUN apt-get update && apt-get install -y curl

# Install Foundry
RUN curl -L https://foundry.paradigm.xyz | bash

# Install bun
RUN curl -fsSL https://bun.sh/install | bash

# Set the working directory in the container
WORKDIR /usr/src/app

# Make port 3000 available to the world outside this container
EXPOSE 3000
