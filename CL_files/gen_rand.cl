
dtype rand(int* seed) // 1 <= *seed < m
{
	int const a = 16807; //ie 7**5
	int const m = 2147483647; //ie 2**31-1

	*seed=((long)((*seed) * a))%m+100;
	return (dtype)(*seed);
}




//���������ǵ������
__kernel void kern_gen_rand(
	__global dtype *out,
	const int mat_size,
	const dtype seed2)
{
	dtype val;
	int u = get_global_id(0);		//����������Ԫ�ص��к�
	int v = get_global_id(1);		//����������Ԫ�ص��к�

	int seed = u+v;

	if (v > u)
		out[u*mat_size + v] = 0;
	else {
		val = fabs(rand(&seed)) / 10000;
		if (u == v) val = val + 10;
		out[u*mat_size + v] = val+seed2;
	}

}