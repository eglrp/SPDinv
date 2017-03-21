
/*
�������ǿ�����������, ����������
*/
__kernel void kern_trigMat_copy(
	__global dtype *in,
	__global dtype *out,
	const int mat_size)
{
	dtype val;
	int u = get_global_id(0);		//����������Ԫ�ص��к�
	int v = get_global_id(1);		//����������Ԫ�ص��к�


	if (v > u) {
		out[u*mat_size + v] = 0;
	}
	else
	{
		out[u*mat_size + v] = in[v*mat_size + u];
	}
}