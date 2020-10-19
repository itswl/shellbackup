package dao;

import com.lagou.RunBoot;
import com.lagou.entity.Position;
import com.lagou.entity.PositionDetail;
import com.lagou.repository.PositionDetailRepository;
import com.lagou.repository.PositionRepository;
import org.apache.shardingsphere.transaction.annotation.ShardingTransactionType;
import org.apache.shardingsphere.transaction.core.TransactionType;
import org.apache.shardingsphere.transaction.core.TransactionTypeHolder;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.junit4.SpringRunner;
import org.springframework.transaction.annotation.Transactional;

import javax.annotation.Resource;

@RunWith(SpringRunner.class)
@SpringBootTest(classes = RunBoot.class)
public class TestShardingTransaction {

    @Resource
    private PositionRepository positionRepository;

    @Resource
    private PositionDetailRepository positionDetailRepository;

    @Test
    @Transactional
//    @ShardingTransactionType(TransactionType.XA)
    @ShardingTransactionType(TransactionType.BASE)
    public void test1(){
//        TransactionTypeHolder.set(TransactionType.XA);
//        TransactionTypeHolder.set(TransactionType.BASE);
        for (int i=1;i<=3;i++){
            Position position = new Position();
            position.setName("root"+i);
            position.setSalary("1000000");
            position.setCity("beijing");
            positionRepository.save(position);

            if (i==3){
                throw new RuntimeException("人为制造异常");
            }

            PositionDetail positionDetail = new PositionDetail();
            positionDetail.setPid(position.getId());
            positionDetail.setDescription("this is a root "+i);
            positionDetailRepository.save(positionDetail);
        }
    }

}
