/ Shared schema for all tick processes. First column is always time, second always sym.
trade:([] time:`timestamp$(); sym:`symbol$(); price:`float$(); size:`long$(); side:`char$())
quote:([] time:`timestamp$(); sym:`symbol$(); bid:`float$(); ask:`float$(); bsize:`long$(); asize:`long$())
