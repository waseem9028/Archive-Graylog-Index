# Archive-Graylog-Index
I have created a script which will search for the indices older than 90days and archive them on common shared file system, in my case it is AWS EFS.

# Introduction:
As we are using the non Enterprise Edition of Graylog, we can't use the Gryalog's Archiving feature.
But, as Graylog uses Elasticsearch we can use Elasticsearch snapshot module to archive the indices from Elasticsearch cluster.

We have created a script to perform the snapshot backup on shared location.
To run this script we need to create the Elasticsearch Snapshot Repository first.

An Elasticsearch snapshots is a backup of running Elasticsearch cluster.
The snapshot module allows us to create snapshots of one or more than one index/indices, or a snapshot of the whole cluster.
The snapshot of indices are stored in a repository on a shared file system, in our case we are using Amazon EFS.

# Version compatibility:
A snapshot of an index created in 5.x can be restored to 6.x.

A snapshot of an index created in 2.x can be restored to 5.x.

A snapshot of an index created in 1.x can be restored to 2.x

snapshots of indices created in 1.x cannot be restored to 5.x or 6.x,

and snapshots of indices created in 2.x cannot be restored to 6.x

# My Environment:
Operating System: Ubuntu

Elasticsearch Version: 6.8.16

AWS EFS mounted at: /mnt/archived (on all nodes of Elasticsearch)

**fstab entry:**

`us-east-1a.fs-0443524se637fd6a59.efs.us-east-1.amazonaws.com:/ /mnt/archived nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 0 0`

# Creating Snapshot Repo:

First, we need to create a directory which would be a backup repo.
As we have mounted the EFS at /mnt/archived location, let's create a new directory here:

`mkdir /mnt/archived/esbackup/`

Provide the elasticsearch permission to write this directory:

`chown -R elasticsearch:elasticsearch /mnt/archived/esbackup/`

# Add path.repo in ES Config:

Backup directory is set, now we have to add the path.repo in the Elasticsearch configuration file "elasticsearch.yml".
To add the repo path, open the `/etc/elasticsearch/elasticsearch.yml` config file by any text editor like "vi" or "nano".
Enter the below line at the end of `/etc/elasticsearch/elasticsearch.yml` file as it is, in all nodes of cluster.

`path.repo: ["/mnt/archived/esbackup"]`

After making changes, we need to restart the Elasticsearch service (Rolling restart on all nodes).

`service elasticsearch restart`

# Create repository:

Now, we are good to create repository.

`curl -XPUT -H "Content-Type: application/json;charset=UTF-8" 'http://localhost:9200/_snapshot/esbackup' -d '{ "type": "fs", "settings": { "location": "/mnt/archived/esbackup", "compress": true } }'`

We can check for repository successfully created or not by running:

`curl -XGET 'http://localhost:9200/_snapshot/_all?pretty'`

![image](https://user-images.githubusercontent.com/10260610/148056908-0a01dbda-813a-4b6b-889f-9588d77287ba.png)

The backup repo has been created successfully.
We can run the archive/basckup script.

# Backup Script:

The backup script (archive.sh) will search for the indices which are older than 90 days and archive them one by one.
You can find the script at path mentioned below in this document.
The script is made to search for the index starting with "graylog_".

# Automate Archiving:

You can set this script in Crontab of Elasticsearch server.

You can write an Ansible playbook to execute this script from CI/CD pipeline.

You can set into API call by using any tool which is compatible to run the API call for Elasticsearch.

