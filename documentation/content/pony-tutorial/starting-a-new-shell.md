---
title: "Starting a new shell"
menu:
  toc:
    parent: "ponytutorial"
    weight: 100
toc: true
---
In this section, we're going to review how you can start a new shell for Wallaroo regardless of how you installed it.

## Wallaroo in Docker

For each Shell you're expected to setup, you'd have to run the following to enter the Wallaroo Docker container:

Enter the Wallaroo Docker container:

```
docker exec -it wally env-setup
```

This command will start a new Bash shell within the container, which will run the `env-setup` script to ensure our Wallaroo code repository is set up.

If your Wallaroo docker container isn't set up or running, you'll get an error with the above command. Please see [Setting Up Your Environment for Wallaroo in Docker](/pony-installation/pony-docker-installation-guide/) for details on how to set up and start your Wallaroo Docker enviroment.

## Wallaroo in Vagrant

For each Shell you're expected to setup, you'd have to run the following to access the Vagrant Box:

```bash
cd ~/wallaroo-tutorial/wallaroo-{{% wallaroo-version %}}/vagrant
vagrant ssh
```

If your Wallaroo vagrant box isn't set up or running, you'll get an error with the above command. Please see [Setting Up Your Environment for Wallaroo in Vagrant](/pony-installation/pony-vagrant-installation-guide/) for details on how to set up and start your Wallaroo Vagrant enviroment.

## Wallaroo from source and Wallaroo Up

For each Shell you're expected to setup, you'd have to run the following to configure the Wallaroo environment:

```bash
cd ~/wallaroo-tutorial/wallaroo-{{% wallaroo-version %}}
source bin/activate
```

This command will set up the environment variables for running Wallaroo Applications.
