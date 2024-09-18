Primer3Plus is a webinterface for Primer3
-----------------------------------------

Dependencies
------------

Primer3Plus requires Primer3, please intall first:

`https://github.com/primer3-org/primer3`


Install a local copy for testing
--------------------------------

`git clone https://github.com/primer3-org/primer3plus.git`

`cd primer3plus`

Setup and run the server
------------------------

The server runs in a terminal

Install the dependencies:

`sudo apt install python3 python3-flask python3-flask-cors npm`

Start the server:

`cd PATH_TO_PRIMER3PLUS/primer3plus`

`export PATH=$PATH:/PATH_TO_PRIMER3/src`

`echo $PATH`

`python server/server.py`

Setup and run the client
------------------------

The client requires a different terminal

Install the dependencies:

`cd PATH_TO_PRIMER3PLUS/primer3plus/client`

`npm install`

Start the client:

`cd PATH_TO_PRIMER3PLUS/primer3plus/client`

`npm run dev`


