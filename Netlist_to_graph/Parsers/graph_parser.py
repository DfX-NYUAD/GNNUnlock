import scipy.sparse as sp
import numpy as np
import json
"""
converts the graph to a suitable format for GraphSAINT

"""
row=[]
col=[]
row_tr=[]
col_tr=[]
connect=[]
cell=[]
connect_tr=[]
feat=[]
labels=[]
feats_test = np.loadtxt("feat.txt", dtype='float32')
count = np.loadtxt("count.txt")
cell = np.genfromtxt("cell.txt", dtype=str)
label = np.loadtxt("label.txt")
arr1inds = count.argsort()
sorted_count = count[arr1inds[0::]]
sorted_feat = feats_test[arr1inds[0::]]
sorted_cell = cell[arr1inds[0::]]
labels = label[arr1inds[0::]]


with open("row.txt", "r") as a_file:
  for line in a_file:
    stripped_line = line.strip()
    row.append(int(stripped_line))
    connect.append(True)


with open("col.txt", "r") as a_file:
  for line in a_file:
    stripped_line = line.strip()
    col.append(int(stripped_line))

with open("row_tr.txt", "r") as a_file:
  for line in a_file:
    stripped_line = line.strip()
    row_tr.append(int(stripped_line))
    connect_tr.append(True)


with open("col_tr.txt", "r") as a_file:
  for line in a_file:
    stripped_line = line.strip()
    col_tr.append(int(stripped_line))
if max(row)!=max(row_tr):
    col_tr.append(max(col))
    row_tr.append(max(row))
    connect_tr.append(False)
with open("feat.txt", "r") as a_file:
  for line in a_file:  
    feat.append((line.strip()).split())
row_ind = np.array(row)
col_ind = np.array(col)
row_ind_tr = np.array(row_tr)
col_ind_tr = np.array(col_tr)
# data to be stored in COO sparse matrix
data = np.array(connect, dtype=bool)
data_tr = np.array(connect_tr, dtype=bool)
mat_coo = sp.coo_matrix((data, (row_ind, col_ind)))
mat_coo_tr = sp.coo_matrix((data_tr, (row_ind_tr, col_ind_tr)))
sparse_matrix=mat_coo.tocsr()
sparse_matrix_tr=mat_coo_tr.tocsr()
sp.save_npz('adj_full.npz', sparse_matrix)
sp.save_npz('adj_train.npz', sparse_matrix_tr)



d = {}
j=0
class1=0
class2=0
class3=0

for line in labels:
    val = line
    val = [int(val)]
    d[str(j)] = val[0]
    if (val[0]==0):
        class1=class1+1
    elif (val[0]==1):
        class2=class2+1
    elif (val[0]==2):
        class3=class3+1
    j=j+1

with open('class_map.json', 'w') as fp:
    json.dump(d, fp)

d_role={}

te_list=[line.rstrip('\n') for line in open("te.txt")]
tr_list= [line.rstrip('\n') for line in open("tr.txt")]
va_list= [line.rstrip('\n') for line in open("va.txt")]
te_list = [int(i) for i in te_list] 
tr_list = [int(i) for i in tr_list] 
va_list = [int(i) for i in va_list] 
d_role['te']= te_list
d_role['tr']= tr_list
d_role['va']= va_list
with open('role.json', 'w') as fp:
    json.dump(d_role, fp)
    

class1_tr=0
class1_va=0
class2_tr=0
class2_va=0
class1_te=0
class2_te=0

for node in d_role['tr']:
    val= d[str(node)]
    if (val==0):
        class1_tr=class1_tr+1
    elif (val==1):
        class2_tr=class2_tr+1


for node in d_role['va']:
    val= d[str(node)]
    if (val==0):
        class1_va=class1_va+1
    elif (val==1):
        class2_va=class2_va+1


for node in d_role['te']:
    val= d[str(node)]
    if (val==0):
        class1_te=class1_te+1
    elif (val==1):
        class2_te=class2_te+1
i=len(feat)

p_class1_tr=(class1_tr/len(tr_list))*100
p_class2_tr=(class2_tr/len(tr_list))*100
p_class1_va=(class1_va/len(va_list))*100
p_class2_va=(class2_va/len(va_list))*100
p_class1_te=(class1_te/len(te_list))*100
p_class2_te=(class2_te/len(te_list))*100


np.save('feats.npy', sorted_feat)
np.save('cell.npy', sorted_cell)
f = open("Dataset_info_log.txt", "w")
f.write("Log file for dataset\n")
f.write("Total # of nodes is " + str(i)+"\n")
f.write("Total # of nodes in testing " + str(len(te_list))+"\n")
f.write("Total # of nodes in training " + str(len(tr_list))+"\n")
f.write("Total # of nodes in validation " + str(len(va_list))+"\n")
f.write("Total # of features for each node is " + str(len(sorted_feat[1]))+"\n")

f.write("P_class1_tr is "+ str(p_class1_tr)+"\n")
f.write("P_class1_te is "+ str(p_class1_te)+"\n")
f.write("P_class1_va is "+ str(p_class1_va)+"\n")
f.write("P_class2_tr is "+ str(p_class2_tr)+"\n")
f.write("P_class2_te is "+ str(p_class2_te)+"\n")
f.write("P_class2_va is "+ str(p_class2_va)+"\n")
f.close()

