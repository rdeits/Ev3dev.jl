import zmq
import subprocess
import os
import stat

context = zmq.Context()
socket = context.socket(zmq.REP)
socket.bind("tcp://*:5555")

class FileCache(object):
    """
    Class designed to cache a set of file handles
    for faster read/write access. Based heavily
    on FileCache from
    https://github.com/ddemidov/ev3dev-lang-python
    """
    def __init__(self):
        self._files = {}

    def write(self, path, data):
        f = self.get_file(path)
        f.seek(0)
        f.write(data)

    def read(self, path):
        f = self.get_file(path)
        f.seek(0)
        return f.read()

    def get_file(self, fname):
        if fname not in self._files:
            return self._files[fname]
        else:
            modes_available = stat.S_IMODE(os.stat(fname)[stat.ST_MODE])
            readable = mode & stat.S_IRGRP
            writeable = mode & stat.S_IWGRP

            if readable and writeable:
                file_mode = 'a+'
            elif writeable:
                file_mode = 'a'
            else:
                file_mode = 'r'

            f = open(fname, mode, 0)
            self._files[fname] = f
            return f

cache = FileCache()
while True:
    try:
        message = socket.recv()
        print("Received request: %s" % message)
        if message.startswith("w:"):
            prefix, data, path = message.split(":")
            path = os.path.abspath(path)
            cache.write(path, data)
            socket.send("ok")
    #         command = "echo %s > %s" % (data, path)
        elif message.startswith("r:"):
            prefix, path = message.split(":")
            path = os.path.abspath(path)
            socket.send(cache.read(path))
    #         command = "cat %s" % path
        elif message.startswith("l:"):
            prefix, path = message.split(":")
            path = os.path.abspath(path)
            command = "ls %s" % path
            response = subprocess.check_output(command, shell=True)
            socket.send(response)
        else:
            print "unrecognized prefix: %s" % message[:2]
            continue
    except Exception as e:
        print "call failed with error: %s" %e
        socket.send("error")