#define dtype double


__kernel void kern_fill_rest(
	__global dtype *in,
	__global dtype *diag,
	const int mat_size);




/*
����S^-1=(L^-t)*(L^-1)��
inΪ�����ǿ����L^-t
*/
__kernel void kern_trigMat_mul(
	__global dtype *in,
	__global dtype *diag,
	const int mat_size)
{
	dtype val;
	int u = get_global_id(0);		//����������Ԫ�ص��к�
	int v = get_global_id(1);		//����������Ԫ�ص��к�

	if (v > u) return;

	//(i,j)��ֵΪin�����i����j�еĳ˻���
	int u_addr, v_addr;
	u_addr = u*mat_size + u;		//��i�п�ʼ��֮ǰ����˶�Ϊ0
	v_addr = v*mat_size + u;
	val = 0;
	for (int k = u; k < mat_size; k++)
	{
		val += in[u_addr++] * in[v_addr++];
	}
	if (u == v)
		diag[u] = val;
	else
		in[u*mat_size + v] = val;

	//call kernel to fill diagonal element
	if (u == 0 && v == 0)
	{
		void(^kernel_fill_rest_wrapper)(void) =
			^{
			kern_fill_rest(in,diag, mat_size);
		};
		size_t    global_size[2] = { mat_size, mat_size};
		//size_t    local_size[2] = { 3,3 };
		ndrange_t ndrange = ndrange_2D(global_size);
		enqueue_kernel(
			get_default_queue(),
			CLK_ENQUEUE_FLAGS_WAIT_KERNEL,
			ndrange, kernel_fill_rest_wrapper
		);

	}
}



/*
1,д��Խ�Ԫ��
2,��������Ԫ�ظ��Ƶ�������
*/
__kernel void kern_fill_rest(
	__global dtype *in,
	__global dtype *diag,
	const int mat_size)
{
	int addr1, addr2;
	int u = get_global_id(0);		//����������Ԫ�ص��к�
	int v = get_global_id(1);		//����������Ԫ�ص��к�

	if (v > u) return;
	
	addr1 = u*mat_size + v;
	if (u == v)
	{
		in[addr1] = diag[u];
	}
	else {
		addr2 = v*mat_size + u;
		in[addr2] = in[addr1];
	}

}