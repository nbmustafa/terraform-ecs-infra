
This repository manages the Terraform scripts to provision ecs cluster.


## AMI Updates

This repository also manages EC2 AMI currency. `ami.Jenkinsfile` provides a pipeline that updates AMIs across your EC2 fleet for a given cluster. It's made possible by using `Rolling Update` mechanism offered by ASG CloudFormation.

### Scheduling AMI update

You can make this pipeline run automatically in Jenkins with the [Parameterized Scheduler](https://wiki.jenkins-ci.org/display/JENKINS/Parameterized+Scheduler+Plugin) plugin and cron.
e.g.

```
  #run against the dev environment at 3am every day
  0 3 * * * % BUILD_ENVIRONMENT=dev
```

## Variable convention

account_config.tf: Contains variables separated by environment
-> vars.tf: Second declaration of variables (including description, type and default values)
--> tf file references through dot notation from var

## Terraform Initialisation and Reinitialisation

Upon first pipeline run, Terraform will initialise a fresh state file into your S3 bucket which will store information about the state of your AWS infrastructure. This file has its own config relating to itself as a file, for example, the KMS key ID used to encrypt this file inside S3.

Whenever you change said config on the state file, Terraform will attempt to reinitialise your infrastructure by copying the state file into the same directory, thus 'overwriting' the old state file with the newly updated state file with new config. This would normally require a user input through CLI, a confirmation check. Due to the way automation works, we cannot provide this input directly. We have added a new batect task 'reinit' to workaround this. When you want to reinitialise your Terraform state, simply change the task that the Jenkinsfile 'Init' stage will run.

```
steps {
  script {
    // env setup
  }
  echo 'Terraform  Init'

  // line to change
}
```

## to add overlay2 for storage performance when running docker follow this link:
https://engineering.loyaltylion.com/using-docker-and-overlayfs-on-amazon-ecs-c0bd00cbb45d
