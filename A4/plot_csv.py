# -*- coding: utf-8 -*-
"""
@author: michi_st
"""

import pandas as pd
import re
from io import StringIO

# Read file
f = open("ex4_example.csv")
file_in = f.read()

# Remove unwanted characters
file_in = file_in.replace("\"","")
file_in = file_in.replace("[","")
file_in = file_in.replace("]","")

# Converte string to memory file
file_io = StringIO(file_in)

# Read memory file as dataframe
df = pd.read_csv(file_io,sep=",",header=6)

# Group by probing range
g = df.groupby("probing_range")

# Calculate mean value of grouped values
g_mean = g.agg(["mean"])
g_sum = g.agg(["sum"])

# Plot mean and sum values
g_sum['msg_reached_goal'].plot(title="Number of received messages")
g_mean['number_of_msg_send'].plot(title="Mean number of received messages")
g_mean['number_of_received'].plot(title="Mean number of received messages")
