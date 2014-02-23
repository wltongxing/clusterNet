#include <stdio.h>
#include <cublas_v2.h>
#include <util.cuh>
#include <basicOps.cuh>
#include <mpi.h>
#include <cuda.h>
#include <assert.h>
#include <util.cuh>
#include <clusterNet.cuh>


void run_neural_network()
{
  Matrix X = read_csv("/home/tim/Downloads/mnist_full_X.csv");
  Matrix y = read_csv("/home/tim/Downloads/mnist_full_y.csv");

  //w1 = gpu.rand(784,1000);
  //w2 = gpu.rand(1000,10);

  printf("Finished!");
}

void MPI_benchmark(int argc, char *argv[])
{
    int myrank;
    MPI_Status status;
    MPI_Init(&argc, &argv);
    MPI_Comm_rank(MPI_COMM_WORLD, &myrank);

    ClusterNet gpu = ClusterNet();
    int batch_rows = 128;
    int w_in = 10000;
    int w_out = 8000;

    //dot
    Matrix B = gpu.rand(w_in,w_out);
    Matrix A = gpu.rand(batch_rows,w_in);
    assert(test_matrix(A,batch_rows,w_in));
    assert(test_matrix(B,w_in,w_out));
    Matrix out = empty(batch_rows, w_out);

    Matrix B1 = gpu.rand(w_in,w_out/2);
    Matrix B2 = gpu.rand(w_in,w_out/2);
    Matrix D = empty(batch_rows,w_out/2);
    Matrix A1 = gpu.rand(batch_rows/2,w_in);
    Matrix big_out = gpu.rand(batch_rows/2,w_out);
    Matrix grand_out = empty(batch_rows, w_out);

    Matrix C = gpu.rand(batch_rows/2,w_in);
    Matrix C_out = empty(batch_rows/2,w_out);

    Matrix E = gpu.rand(batch_rows/4,w_in);
    Matrix E_out = empty(batch_rows/4,w_out);
    Matrix E_merge = empty(batch_rows/2,w_out);
    Matrix E_merge2 = empty(batch_rows/2,w_out);

    //add

    /*
    B = gpu.rand(w_in,w_out);
    A = gpu.rand(w_in,w_out);
    out = empty(w_in, w_out);
    A1 = gpu.rand(w_in/2,w_out);
    Matrix A2 = gpu.rand(w_in/2,w_out);
    D = empty(w_in/2,w_out);
*/

    cudaEvent_t* startstop = tick();
    for(int i = 0; i< 100; i++)
    {
      gpu.dot(A,B, out);
	//add(A, B, out);
    }
    printf("Direct compute:\n");
    tock(startstop);


    out = empty(batch_rows,w_out/2);
    Matrix out2 = empty(batch_rows,w_out/2);
    startstop = tick();
    for(int i = 0; i< 100; i++)
    {
      gpu.dot(A,B1, out);
      gpu.dot(A,B2, out2);
      merge(out,out2,grand_out);
    }
    printf("Direct compute x2:\n");
    tock(startstop);

    Matrix mergemat = empty(batch_rows, w_out);
    out = empty(batch_rows,w_out/2);
    startstop = tick();
    //out = empty(w_in/2,w_out);
    for(int i = 0; i < 100; i++)
    {
	    if(myrank == 0)
	    {
		gpu.dot(A,B1, out);
    		//add(A1, B,out);
		MPI_Send(out.data, out.size, MPI_FLOAT, 1, 100, MPI_COMM_WORLD);
	    }
	    else
	    {
		gpu.dot(A,B2, out);
		//add(A2,B, out);
	 	MPI_Recv(D.data, D.size, MPI_FLOAT, 0, 100, MPI_COMM_WORLD, &status);
                merge(out,D, mergemat);
	    }

    }

    if(myrank == 1)
    {
      printf("GPUDirect RDMA:\n");
      tock(startstop);
    }

    out = empty(batch_rows/2,w_out);
    startstop = tick();
    //out = empty(w_in/2,w_out);
    for(int i = 0; i < 100; i++)
    {
	    if(myrank == 0)
	    {
		gpu.dot(C,B, out);
    		//add(A1, B,out);
		MPI_Send(out.data, out.size, MPI_FLOAT, 1, 100, MPI_COMM_WORLD);
	    }
	    else
	    {
		gpu.dot(C,B, out);
		//add(A2,B, out);
	 	MPI_Recv(C_out.data, C_out.size, MPI_FLOAT, 0, 100, MPI_COMM_WORLD, &status);
                merge(out,C_out, grand_out);
	    }

    }

    if(myrank == 1)
    {
      printf("GPUDirect RDMA batch:\n");
      tock(startstop);
    }








    MPI_Finalize();

}







int main(int argc, char *argv[])
{

  //MPI_benchmark(argc, argv);
	ClusterNet gpu = ClusterNet(argc, argv, 12345);







}


