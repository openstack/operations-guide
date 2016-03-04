===============
Lay of the Land
===============

This chapter helps you set up your working environment and use it to
take a look around your cloud.

Using the OpenStack Dashboard for Administration
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

As a cloud administrative user, you can use the OpenStack dashboard to
create and manage projects, users, images, and flavors. Users are
allowed to create and manage images within specified projects and to
share images, depending on the Image service configuration. Typically,
the policy configuration allows admin users only to set quotas and
create and manage services. The dashboard provides an Admin tab with a
System Panel and an Identity tab. These interfaces give you access to
system information and usage as well as to settings for configuring what
end users can do. Refer to the `OpenStack Admin User
Guide <http://docs.openstack.org/user-guide-admin/dashboard.html>`_ for
detailed how-to information about using the dashboard as an admin
user.working environment dashboarddashboard

Command-Line Tools
~~~~~~~~~~~~~~~~~~

We recommend using a combination of the OpenStack command-line interface
(CLI) tools and the OpenStack dashboard for administration. Some users
with a background in other cloud technologies may be using the EC2
Compatibility API, which uses naming conventions somewhat different from
the native API. We highlight those differences.working environment
command-line tools

We strongly suggest that you install the command-line clients from the
`Python Package Index <https://pypi.python.org/pypi>`_ (PyPI) instead
of from the distribution packages. The clients are under heavy
development, and it is very likely at any given time that the version of
the packages distributed by your operating-system vendor are out of
date.command-line tools Python Package Index (PyPI)pip utilityPython
Package Index (PyPI)

The pip utility is used to manage package installation from the PyPI
archive and is available in the python-pip package in most Linux
distributions. Each OpenStack project has its own client, so depending
on which services your site runs, install some or all of the
followingneutron python-neutronclientswift
python-swiftclientcinderkeystoneglance python-glanceclientnova
python-novaclient packages:

-  python-novaclient (nova CLI)

-  python-glanceclient (glance CLI)

-  python-keystoneclient (keystone CLI)

-  python-cinderclient (cinder CLI)

-  python-swiftclient (swift CLI)

-  python-neutronclient (neutron CLI)

Installing the Tools
--------------------

To install (or upgrade) a package from the PyPI archive with pip,
command-line tools installingas root:

::

    # pip install [--upgrade] <package-name>

To remove the package:

::

    # pip uninstall <package-name>

If you need even newer versions of the clients, pip can install directly
from the upstream git repository using the ``-e`` flag. You must specify
a name for the Python egg that is installed. For example:

::

    # pip install -e \
      git+https://git.openstack.org/openstack/python-novaclient#egg=python-novaclient

If you support the EC2 API on your cloud, you should also install the
euca2ools package or some other EC2 API tool so that you can get the
same view your users have. Using EC2 API-based tools is mostly out of
the scope of this guide, though we discuss getting credentials for use
with it.

Administrative Command-Line Tools
---------------------------------

There are also several ``*-manage`` command-line tools. These are
installed with the project's services on the cloud controller and do not
need to be installed\*-manage command-line toolscommand-line tools
administrative separately:

-  ``nova-manage``

-  ``glance-manage``

-  ``keystone-manage``

-  ``cinder-manage``

Unlike the CLI tools mentioned above, the ``*-manage`` tools must be run
from the cloud controller, as root, because they need read access to the
config files such as ``/etc/nova/nova.conf`` and to make queries
directly against the database rather than against the OpenStack API
endpoints.API (application programming interface) API endpointendpoints
API endpoint

.. warning::

    The existence of the ``*-manage`` tools is a legacy issue. It is a
    goal of the OpenStack project to eventually migrate all of the
    remaining functionality in the ``*-manage`` tools into the API-based
    tools. Until that day, you need to SSH into the cloud controller
    node to perform some maintenance operations that require one of the
    ``*-manage`` tools.cloud controller nodes command-line tools and

Getting Credentials
-------------------

You must have the appropriate credentials if you want to use the
command-line tools to make queries against your OpenStack cloud. By far,
the easiest way to obtain authentication credentials to use with
command-line clients is to use the OpenStack dashboard. Select Project,
click the Project tab, and click Access & Security on the Compute
category. On the Access & Security page, click the API Access tab to
display two buttons, Download OpenStack RC File and Download EC2
Credentials, which let you generate files that you can source in your
shell to populate the environment variables the command-line tools
require to know where your service endpoints and your authentication
information are. The user you logged in to the dashboard dictates the
filename for the openrc file, such as ``demo-openrc.sh``. When logged in
as admin, the file is named
``admin-openrc.sh``.credentialsauthenticationcommand-line tools getting
credentials

The generated file looks something like this:

::

    #!/bin/bash

    # With the addition of Keystone, to use an openstack cloud you should
    # authenticate against keystone, which returns a **Token** and **Service
    # Catalog**. The catalog contains the endpoint for all services the
    # user/tenant has access to--including nova, glance, keystone, swift.
    #
    # *NOTE*: Using the 2.0 *auth api* does not mean that compute api is 2.0.
    # We use the 1.1 *compute api*
    export OS_AUTH_URL=http://203.0.113.10:5000/v2.0

    # With the addition of Keystone we have standardized on the term **tenant**
    # as the entity that owns the resources.
    export OS_TENANT_ID=98333aba48e756fa8f629c83a818ad57
    export OS_TENANT_NAME="test-project"

    # In addition to the owning entity (tenant), openstack stores the entity
    # performing the action as the **user**.
    export OS_USERNAME=demo

    # With Keystone you pass the keystone password.
    echo "Please enter your OpenStack Password: "
    read -s OS_PASSWORD_INPUT
    export OS_PASSWORD=$OS_PASSWORD_INPUT

.. warning::

    This does not save your password in plain text, which is a good
    thing. But when you source or run the script, it prompts you for
    your password and then stores your response in the environment
    variable ``OS_PASSWORD``. It is important to note that this does
    require interactivity. It is possible to store a value directly in
    the script if you require a noninteractive operation, but you then
    need to be extremely cautious with the security and permissions of
    this file.passwordssecurity issues passwords

EC2 compatibility credentials can be downloaded by selecting Project,
then Compute, then Access & Security, then API Access to display the
Download EC2 Credentials button. Click the button to generate a ZIP file
with server x509 certificates and a shell script fragment. Create a new
directory in a secure location because these are live credentials
containing all the authentication information required to access your
cloud identity, unlike the default ``user-openrc``. Extract the ZIP file
here. You should have ``cacert.pem``, ``cert.pem``, ``ec2rc.sh``, and
``pk.pem``. The ``ec2rc.sh`` is similar to this:access key

::

    #!/bin/bash

    NOVARC=$(readlink -f "${BASH_SOURCE:-${0}}" 2>/dev/null) ||\
    NOVARC=$(python -c 'import os,sys; \
    print os.path.abspath(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE:-${0}}")
    NOVA_KEY_DIR=${NOVARC%/*}
    export EC2_ACCESS_KEY=df7f93ec47e84ef8a347bbb3d598449a
    export EC2_SECRET_KEY=ead2fff9f8a344e489956deacd47e818
    export EC2_URL=http://203.0.113.10:8773/services/Cloud
    export EC2_USER_ID=42 # nova does not use user id, but bundling requires it
    export EC2_PRIVATE_KEY=${NOVA_KEY_DIR}/pk.pem
    export EC2_CERT=${NOVA_KEY_DIR}/cert.pem
    export NOVA_CERT=${NOVA_KEY_DIR}/cacert.pem
    export EUCALYPTUS_CERT=${NOVA_CERT} # euca-bundle-image seems to require this

    alias ec2-bundle-image="ec2-bundle-image --cert $EC2_CERT --privatekey \
    $EC2_PRIVATE_KEY --user 42 --ec2cert $NOVA_CERT"
    alias ec2-upload-bundle="ec2-upload-bundle -a $EC2_ACCESS_KEY -s \
    $EC2_SECRET_KEY --url $S3_URL --ec2cert $NOVA_CERT"

To put the EC2 credentials into your environment, source the
``ec2rc.sh`` file.

Inspecting API Calls
--------------------

The command-line tools can be made to show the OpenStack API calls they
make by passing the ``--debug`` flag to them.API (application
programming interface) API calls, inspectingcommand-line tools
inspecting API calls For example:

::

    # nova --debug list

This example shows the HTTP requests from the client and the responses
from the endpoints, which can be helpful in creating custom tools
written to the OpenStack API.

Using cURL for further inspection
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Underlying the use of the command-line tools is the OpenStack API, which
is a RESTful API that runs over HTTP. There may be cases where you want
to interact with the API directly or need to use it because of a
suspected bug in one of the CLI tools. The best way to do this is to use
a combination of \ `cURL <http://curl.haxx.se/>`_ and another tool,
such as \ `jq <http://stedolan.github.io/jq/>`_, to parse the JSON from
the responses.authentication tokenscURL

The first thing you must do is authenticate with the cloud using your
credentials to get an authentication token.

Your credentials are a combination of username, password, and tenant
(project). You can extract these values from the ``openrc.sh`` discussed
above. The token allows you to interact with your other service
endpoints without needing to reauthenticate for every request. Tokens
are typically good for 24 hours, and when the token expires, you are
alerted with a 401 (Unauthorized) response and you can request another
token.catalog

1. Look at your OpenStack service catalog:

   .. code:: bash

       $ curl -s -X POST http://203.0.113.10:35357/v2.0/tokens \
       -d '{"auth": {"passwordCredentials": {"username":"test-user", \
                                             "password":"test-password"},  \
                                             "tenantName":"test-project"}}' \
       -H "Content-type: application/json" | jq .

2. Read through the JSON response to get a feel for how the catalog is
   laid out.

   To make working with subsequent requests easier, store the token in
   an environment variable:

   .. code:: bash

       $ TOKEN=`curl -s -X POST http://203.0.113.10:35357/v2.0/tokens \
       -d '{"auth": {"passwordCredentials": {"username":"test-user",  \
                                             "password":"test-password"},  \
                                             "tenantName":"test-project"}}' \
       -H "Content-type: application/json" |  jq -r .access.token.id`

   Now you can refer to your token on the command line as ``$TOKEN``.

3. Pick a service endpoint from your service catalog, such as compute.
   Try a request, for example, listing instances (servers):

   ::

       $ curl -s \
       -H "X-Auth-Token: $TOKEN" \
       http://203.0.113.10:8774/v2/98333aba48e756fa8f629c83a818ad57/servers | jq .

To discover how API requests should be structured, read the `OpenStack
API Reference <http://developer.openstack.org/api-ref.html>`_. To chew
through the responses using jq, see the `jq
Manual <http://stedolan.github.io/jq/manual/>`_.

The ``-s flag`` used in the cURL commands above are used to prevent
the progress meter from being shown. If you are having trouble running
cURL commands, you'll want to remove it. Likewise, to help you
troubleshoot cURL commands, you can include the ``-v`` flag to show you
the verbose output. There are many more extremely useful features in
cURL; refer to the man page for all the options.

Servers and Services
--------------------

As an administrator, you have a few ways to discover what your OpenStack
cloud looks like simply by using the OpenStack tools available. This
section gives you an idea of how to get an overview of your cloud, its
shape, size, and current state.services obtaining overview ofservers
obtaining overview ofcloud computing cloud overviewcommand-line tools
servers and services

First, you can discover what servers belong to your OpenStack cloud by
running:

::

    # nova-manage service list | sort

The output looks like the following:

::

    Binary           Host              Zone Status  State Updated_At
    nova-cert        cloud.example.com nova enabled  :-)  2013-02-25 19:32:38
    nova-compute     c01.example.com   nova enabled  :-)  2013-02-25 19:32:35
    nova-compute     c02.example.com   nova enabled  :-)  2013-02-25 19:32:32
    nova-compute     c03.example.com   nova enabled  :-)  2013-02-25 19:32:36
    nova-compute     c04.example.com   nova enabled  :-)  2013-02-25 19:32:32
    nova-compute     c05.example.com   nova enabled  :-)  2013-02-25 19:32:41
    nova-conductor   cloud.example.com nova enabled  :-)  2013-02-25 19:32:40
    nova-consoleauth cloud.example.com nova enabled  :-)  2013-02-25 19:32:36
    nova-network     cloud.example.com nova enabled  :-)  2013-02-25 19:32:32
    nova-scheduler   cloud.example.com nova enabled  :-)  2013-02-25 19:32:33

The output shows that there are five compute nodes and one cloud
controller. You see a smiley face, such as ``:-)``, which indicates that
the services are up and running. If a service is no longer available,
the ``:-)`` symbol changes to ``XXX``. This is an indication that you
should troubleshoot why the service is down.

If you are using cinder, run the following command to see a similar
listing:

::

    # cinder-manage host list | sort

::

    host              zone
    c01.example.com   nova
    c02.example.com   nova
    c03.example.com   nova
    c04.example.com   nova
    c05.example.com   nova
    cloud.example.com nova

With these two tables, you now have a good overview of what servers and
services make up your cloud.

You can also use the Identity service (keystone) to see what services
are available in your cloud as well as what endpoints have been
configured for the services.Identity displaying services and endpoints
with

The following command requires you to have your shell environment
configured with the proper administrative variables:

::

    $ openstack catalog list

::

    +----------+------------+---------------------------------------------------------------------------------+
    | Name     | Type       | Endpoints                                                                       |
    +----------+------------+---------------------------------------------------------------------------------+
    | nova     | compute    | RegionOne                                                                       |
    |          |            |   publicURL: http://192.168.122.10:8774/v2/9faa845768224258808fc17a1bb27e5e     |
    |          |            |   internalURL: http://192.168.122.10:8774/v2/9faa845768224258808fc17a1bb27e5e   |
    |          |            |   adminURL: http://192.168.122.10:8774/v2/9faa845768224258808fc17a1bb27e5e      |
    |          |            |                                                                                 |
    | cinderv2 | volumev2   | RegionOne                                                                       |
    |          |            |   publicURL: http://192.168.122.10:8776/v2/9faa845768224258808fc17a1bb27e5e     |
    |          |            |   internalURL: http://192.168.122.10:8776/v2/9faa845768224258808fc17a1bb27e5e   |
    |          |            |   adminURL: http://192.168.122.10:8776/v2/9faa845768224258808fc17a1bb27e5e      |
    |          |            |                                                                                 |

The preceding output has been truncated to show only two services. You
will see one service entry for each service that your cloud provides.
Note how the endpoint domain can be different depending on the endpoint
type. Different endpoint domains per type are not required, but this can
be done for different reasons, such as endpoint privacy or network
traffic segregation.

You can find the version of the Compute installation by using the
``nova-manage`` command:

::

    # nova-manage version

Diagnose Your Compute Nodes
---------------------------

You can obtain extra information about virtual machines that are
running—their CPU usage, the memory, the disk I/O or network I/O—per
instance, by running the ``nova diagnostics`` command withcompute nodes
diagnosingcommand-line tools compute node diagnostics a server ID:

::

    $ nova diagnostics <serverID>

The output of this command varies depending on the hypervisor because
hypervisors support different attributes.hypervisors compute node
diagnosis and The following demonstrates the difference between the two
most popular hypervisors. Here is example output when the hypervisor is
Xen:

::

    +----------------+-----------------+
    |    Property    |      Value      |
    +----------------+-----------------+
    | cpu0           | 4.3627          |
    | memory         | 1171088064.0000 |
    | memory_target  | 1171088064.0000 |
    | vbd_xvda_read  | 0.0             |
    | vbd_xvda_write | 0.0             |
    | vif_0_rx       | 3223.6870       |
    | vif_0_tx       | 0.0             |
    | vif_1_rx       | 104.4955        |
    | vif_1_tx       | 0.0             |
    +----------------+-----------------+

While the command should work with any hypervisor that is controlled
through libvirt (KVM, QEMU, or LXC), it has been tested only with KVM.
Here is the example output when the hypervisor is KVM:

::

    +------------------+------------+
    | Property         | Value      |
    +------------------+------------+
    | cpu0_time        | 2870000000 |
    | memory           | 524288     |
    | vda_errors       | -1         |
    | vda_read         | 262144     |
    | vda_read_req     | 112        |
    | vda_write        | 5606400    |
    | vda_write_req    | 376        |
    | vnet0_rx         | 63343      |
    | vnet0_rx_drop    | 0          |
    | vnet0_rx_errors  | 0          |
    | vnet0_rx_packets | 431        |
    | vnet0_tx         | 4905       |
    | vnet0_tx_drop    | 0          |
    | vnet0_tx_errors  | 0          |
    | vnet0_tx_packets | 45         |
    +------------------+------------+

Network Inspection
~~~~~~~~~~~~~~~~~~

To see which fixed IP networks are configured in your cloud, you can use
the ``nova`` command-line client to get the IP ranges:networks
inspection ofworking environment network inspection

::

    $ nova network-list
    +--------------------------------------+--------+--------------+
    | ID                                   | Label  | Cidr         |
    +--------------------------------------+--------+--------------+
    | 3df67919-9600-4ea8-952e-2a7be6f70774 | test01 |  10.1.0.0/24 |
    | 8283efb2-e53d-46e1-a6bd-bb2bdef9cb9a | test02 |  10.1.1.0/24 |
    +--------------------------------------+--------+--------------+

The ``nova-manage`` tool can provide some additional details:

::

    # nova-manage network list
    id IPv4        IPv6 start address DNS1 DNS2 VlanID project   uuid
    1  10.1.0.0/24 None 10.1.0.3      None None 300    2725bbd   beacb3f2
    2  10.1.1.0/24 None 10.1.1.3      None None 301    none      d0b1a796

This output shows that two networks are configured, each network
containing 255 IPs (a /24 subnet). The first network has been assigned
to a certain project, while the second network is still open for
assignment. You can assign this network manually; otherwise, it is
automatically assigned when a project launches its first instance.

To find out whether any floating IPs are available in your cloud, run:

::

    # nova-manage floating list

::

    2725bb...59f43f 1.2.3.4 None            nova vlan20
    None            1.2.3.5 48a415...b010ff nova vlan20

Here, two floating IPs are available. The first has been allocated to a
project, while the other is unallocated.

Users and Projects
~~~~~~~~~~~~~~~~~~

To see a list of projects that have been added to the cloud,projects
obtaining list of currentuser management listing usersworking
environment users and projects run:

::

    $ openstack project list

::

    +----------------------------------+--------------------+
    | ID                               | Name               |
    +----------------------------------+--------------------+
    | 422c17c0b26f4fbe9449f37a5621a5e6 | alt_demo           |
    | 5dc65773519248f3a580cfe28ba7fa3f | demo               |
    | 9faa845768224258808fc17a1bb27e5e | admin              |
    | a733070a420c4b509784d7ea8f6884f7 | invisible_to_admin |
    | aeb3e976e7794f3f89e4a7965db46c1e | service            |
    +----------------------------------+--------------------+

To see a list of users, run:

::

    $ openstack user list

::

    +----------------------------------+----------+
    | ID                               | Name     |
    +----------------------------------+----------+
    | 5837063598694771aedd66aa4cddf0b8 | demo     |
    | 58efd9d852b74b87acc6efafaf31b30e | cinder   |
    | 6845d995a57a441f890abc8f55da8dfb | glance   |
    | ac2d15a1205f46d4837d5336cd4c5f5a | alt_demo |
    | d8f593c3ae2b47289221f17a776a218b | admin    |
    | d959ec0a99e24df0b7cb106ff940df20 | nova     |
    +----------------------------------+----------+

.. note::

    Sometimes a user and a group have a one-to-one mapping. This happens
    for standard system accounts, such as cinder, glance, nova, and
    swift, or when only one user is part of a group.

Running Instances
~~~~~~~~~~~~~~~~~

To see a list of running instances,instances list of runningworking
environment running instances run:

::

    $ nova list --all-tenants

::

    +-----+------------------+--------+-------------------------------------------+
    | ID  | Name             | Status | Networks                                  |
    +-----+------------------+--------+-------------------------------------------+
    | ... | Windows          | ACTIVE | novanetwork_1=10.1.1.3, 199.116.232.39    |
    | ... | cloud controller | ACTIVE | novanetwork_0=10.1.0.6; jtopjian=10.1.2.3 |
    | ... | compute node 1   | ACTIVE | novanetwork_0=10.1.0.4; jtopjian=10.1.2.4 |
    | ... | devbox           | ACTIVE | novanetwork_0=10.1.0.3                    |
    | ... | devstack         | ACTIVE | novanetwork_0=10.1.0.5                    |
    | ... | initial          | ACTIVE | nova_network=10.1.7.4, 10.1.8.4           |
    | ... | lorin-head       | ACTIVE | nova_network=10.1.7.3, 10.1.8.3           |
    +-----+------------------+--------+-------------------------------------------+

Unfortunately, this command does not tell you various details about the
running instances, such as what compute node the instance is running on,
what flavor the instance is, and so on. You can use the following
command to view details about individual instances:config drive

::

    $ nova show <uuid>

For example:

::

    # nova show 81db556b-8aa5-427d-a95c-2a9a6972f630

::

    +-------------------------------------+-----------------------------------+
    | Property                            | Value                             |
    +-------------------------------------+-----------------------------------+
    | OS-DCF:diskConfig                   | MANUAL                            |
    | OS-EXT-SRV-ATTR:host                | c02.example.com                   |
    | OS-EXT-SRV-ATTR:hypervisor_hostname | c02.example.com                   |
    | OS-EXT-SRV-ATTR:instance_name       | instance-00000029                 |
    | OS-EXT-STS:power_state              | 1                                 |
    | OS-EXT-STS:task_state               | None                              |
    | OS-EXT-STS:vm_state                 | active                            |
    | accessIPv4                          |                                   |
    | accessIPv6                          |                                   |
    | config_drive                        |                                   |
    | created                             | 2013-02-13T20:08:36Z              |
    | flavor                              | m1.small (6)                      |
    | hostId                              | ...                               |
    | id                                  | ...                               |
    | image                               | Ubuntu 12.04 cloudimg amd64 (...) |
    | key_name                            | jtopjian-sandbox                  |
    | metadata                            | {}                                |
    | name                                | devstack                          |
    | novanetwork_0 network               | 10.1.0.5                          |
    | progress                            | 0                                 |
    | security_groups                     | [{u'name': u'default'}]           |
    | status                              | ACTIVE                            |
    | tenant_id                           | ...                               |
    | updated                             | 2013-02-13T20:08:59Z              |
    | user_id                             | ...                               |
    +-------------------------------------+-----------------------------------+

This output shows that an instance named ``devstack`` was created from
an Ubuntu 12.04 image using a flavor of ``m1.small`` and is hosted on
the compute node ``c02.example.com``.

Summary
~~~~~~~

We hope you have enjoyed this quick tour of your working environment,
including how to interact with your cloud and extract useful
information. From here, you can use the `Admin User
Guide <http://docs.openstack.org/user-guide-admin/>`_ as your
reference for all of the command-line functionality in your cloud.
